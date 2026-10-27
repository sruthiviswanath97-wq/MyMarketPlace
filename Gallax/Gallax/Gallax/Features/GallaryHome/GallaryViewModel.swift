//
//  GallaryViewModel.swift
//  Gallax
//
//  Created by sruthi.e01 on 25/10/26.
//

import Foundation
import SwiftData

@MainActor
@Observable
final class GallaryViewModel {

    private(set) var items: [GalleryItem] = []
    private(set) var isRefreshing = false
    private(set) var errorMessage: String?

    @ObservationIgnored private var store: GalleryDataStore?
    @ObservationIgnored private var syncService: SyncService?
    @ObservationIgnored private let monitor: NetworkMonitor

    
    init(monitor: NetworkMonitor? = nil) {
        self.monitor = monitor ?? .shared
    }

    // MARK: - Derived state for the header

    var totalCount: Int { items.count }
    var syncedCount: Int { items.filter { $0.syncStatus == .synced }.count }
    var unsyncedCount: Int { totalCount - syncedCount }
    var favoriteCount: Int { items.filter(\.isFavorite).count }

    var isConnected: Bool { monitor.isConnected }
    var connectionLabel: String { monitor.statusLabel }
    var syncPhase: SyncService.Phase { syncService?.phase ?? .idle }
    var lastSyncedAt: Date? { syncService?.lastSyncedAt }

    func configure(modelContext: ModelContext, syncService: SyncService) {
        guard store == nil else { return }
        self.store = GalleryDataStore(context: modelContext)
        self.syncService = syncService

        monitor.start()
        monitor.onReconnect = { [weak self] in
            Task { await self?.refresh() }
        }
        reload()
    }

    func reload() {
        guard let store else { return }
        do {
            items = try store.fetchItems()
        } catch {
            errorMessage = error.localizedDescription
        }
    }


    func refresh() async {
        guard let syncService else { return }
        isRefreshing = true
        await syncService.sync()
        isRefreshing = false
        if case .failed(let message) = syncService.phase, monitor.isConnected {
            errorMessage = message
        }
        reload()
    }

    func toggleFavorite(_ item: GalleryItem) {
        guard let store, let syncService else { return }
        item.isFavorite.toggle()
        item.updatedAt = .now
        do {
            try syncService.enqueue(.update, for: item)
            try store.save()
            reload()
            Task { await drainIfOnline() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ item: GalleryItem) {
        guard let store, let syncService else { return }
        item.isDeleted = true
        item.updatedAt = .now
        do {
            try syncService.enqueue(.delete, for: item)
            try store.save()
            reload()
            Task { await drainIfOnline() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    private func drainIfOnline() async {
        guard monitor.isConnected, let syncService else { return }
        await syncService.pushPendingChanges()
        reload()
    }
}
