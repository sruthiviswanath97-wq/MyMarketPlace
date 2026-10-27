//
//  SyncService.swift
//  Gallax
//
//  Created by sruthi.e01 on 25/10/26.
//

import Foundation

@MainActor
protocol SyncServicing: AnyObject {
    func enqueue(_ operation: SyncOperation, for item: GalleryItem) throws
    func pushPendingChanges() async
    func pullRemoteItems() async throws
    func sync() async
}


@MainActor
@Observable
final class SyncService: SyncServicing {

    enum Phase: Equatable {
        case idle
        case syncing
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var lastSyncedAt: Date?

    @ObservationIgnored private let store: GalleryDataStoring
    @ObservationIgnored private let service: GalleryServicing
    @ObservationIgnored private let monitor: NetworkMonitoring
    @ObservationIgnored private var isSyncing = false
    @ObservationIgnored private var isDraining = false

    static let maxRetryCount = 5

    init(store: GalleryDataStoring,
         service: GalleryServicing,
         monitor: NetworkMonitoring) {
        self.store = store
        self.service = service
        self.monitor = monitor
    }


    func enqueue(_ operation: SyncOperation, for item: GalleryItem) throws {
        let payload = ChangePayload(title: item.title,
                                    description: item.itemDescription,
                                    isFavorite: item.isFavorite)
        let change = PendingChange(itemLocalId: item.localId,
                                   operation: operation,
                                   payload: payload,
                                   clientUpdatedAt: item.updatedAt)
        store.insert(change)
        item.syncStatus = .pending
        try store.save()
    }


    func sync() async {
        guard !isSyncing else { return }
        guard monitor.isConnected else {
            phase = .failed("Offline")
            return
        }
        isSyncing = true
        phase = .syncing
        defer { isSyncing = false }

        await pushPendingChanges()

        do {
            try await pullRemoteItems()
            lastSyncedAt = .now
            phase = .idle
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }


    func pushPendingChanges() async {
        guard !isDraining else { return }
        isDraining = true
        defer { isDraining = false }

        guard let changes = try? store.fetchPendingChanges() else { return }
        for change in changes where change.status == .syncing {
            change.status = .pending
        }

        for change in changes where change.retryCount < Self.maxRetryCount {
            guard monitor.isConnected else { break }
            await push(change)
        }
        try? store.save()
    }

    private func push(_ change: PendingChange) async {
        let item = try? store.fetchItem(localId: change.itemLocalId)

        if item == nil && change.operation != .delete {
            store.delete(change)
            return
        }

        change.status = .syncing

        do {
            switch change.operation {
            case .create:
                guard let item else { break }
                let remote = try await service.createItem(title: item.title,
                                                          description: item.itemDescription)
                item.remoteId = remote.remoteId
                item.remoteUpdatedAt = remote.updatedAt ?? .now
                item.syncStatus = .synced

            case .update:
                guard let item else { break }
                guard let remoteId = item.remoteId else {
                    // Never created on the server yet: promote to a create.
                    change.operation = .create
                    change.status = .pending
                    return
                }
                let remote = try await service.updateItem(remoteId: remoteId,
                                                          title: item.title,
                                                          description: item.itemDescription)
                item.remoteUpdatedAt = remote.updatedAt ?? .now
                item.syncStatus = .synced

            case .delete:
                if let remoteId = item?.remoteId ?? nil {
                    try await service.deleteItem(remoteId: remoteId)
                }
                if let item { store.delete(item) }
            }

            change.status = .synced
            change.lastError = nil
            store.delete(change)

        } catch {
            if Self.isNotFound(error), handleMissingRemoteRecord(for: change, item: item) {
                return
            }
            change.status = .failed
            change.retryCount += 1
            change.lastError = error.localizedDescription
            item?.syncStatus = .failed
        }
    }

    private func handleMissingRemoteRecord(for change: PendingChange,
                                           item: GalleryItem?) -> Bool {
        switch change.operation {
        case .delete:
            if let item { store.delete(item) }

        case .update:
            guard let item, item.isLocallyCreated else { return false }
            item.remoteUpdatedAt = item.updatedAt
            item.syncStatus = .synced

        case .create:
            return false
        }

        change.status = .synced
        change.lastError = nil
        store.delete(change)
        return true
    }

    private static func isNotFound(_ error: Error) -> Bool {
        if case APIError.badStatus(404) = error { return true }
        return false
    }

    // MARK: - Pull

    func pullRemoteItems() async throws {
        let remoteItems = try await service.fetchItems()
        let locals = try store.fetchItems()
        var byRemoteId: [String: GalleryItem] = [:]
        for local in locals {
            if let remoteId = local.remoteId {
                byRemoteId[remoteId] = local
            }
        }

        for remote in remoteItems {
            if let local = byRemoteId[remote.remoteId] {
                try reconcile(local: local, with: remote)
            } else {
                let item = GalleryItem(remoteId: remote.remoteId,
                                       title: remote.title,
                                       itemDescription: remote.description,
                                       imageURL: remote.imageURL,
                                       updatedAt: remote.updatedAt ?? .now,
                                       remoteUpdatedAt: remote.updatedAt,
                                       syncStatus: .synced)
                store.insert(item)
            }
        }
        try store.save()
    }

    private func reconcile(local: GalleryItem, with remote: RemoteItem) throws {
        let pendingCount = (try? store.pendingChangeCount(forItem: local.localId)) ?? 0
        let resolution = ConflictResolver.resolve(localUpdatedAt: local.updatedAt,
                                                  remoteUpdatedAt: remote.updatedAt,
                                                  hasPendingLocalChanges: pendingCount > 0)

        switch resolution {
        case .useRemote:
            local.title = remote.title
            local.itemDescription = remote.description
            local.imageURL = remote.imageURL
            local.remoteUpdatedAt = remote.updatedAt
            local.updatedAt = remote.updatedAt ?? .now
            local.syncStatus = .synced

        case .keepLocal:
            local.remoteUpdatedAt = remote.updatedAt
            local.syncStatus = .pending

        case .noChange:
            local.imageURL = local.imageURL ?? remote.imageURL
            local.remoteUpdatedAt = remote.updatedAt
            if pendingCount == 0 {
                local.syncStatus = .synced
            }
        }
    }
}
