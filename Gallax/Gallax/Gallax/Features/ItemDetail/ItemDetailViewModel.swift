//
//  ItemDetailViewModel.swift
//  Gallax
//
//  Created by sruthi.e01 on 25/10/26.
//

import Foundation
import SwiftData

@MainActor
@Observable
final class ItemDetailViewModel {

    let item: GalleryItem

    var draftTitle: String
    var draftDescription: String
    var isEditing = false
    private(set) var errorMessage: String?

    @ObservationIgnored private let store: GalleryDataStore
    @ObservationIgnored private let syncService: SyncService
    @ObservationIgnored private let monitor: NetworkMonitor

    init(item: GalleryItem,
         modelContext: ModelContext,
         syncService: SyncService,
         monitor: NetworkMonitor? = nil) {
        self.item = item
        self.draftTitle = item.title
        self.draftDescription = item.itemDescription
        self.monitor = monitor ?? .shared
        self.store = GalleryDataStore(context: modelContext)
        self.syncService = syncService
    }

    var isConnected: Bool { monitor.isConnected }

    var canSave: Bool {
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = draftDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= 120 else { return false }
        guard !description.isEmpty, description.count <= 1000 else { return false }
        return title != item.title || description != item.itemDescription
    }

    func beginEditing() {
        draftTitle = item.title
        draftDescription = item.itemDescription
        isEditing = true
    }

    func cancelEditing() {
        draftTitle = item.title
        draftDescription = item.itemDescription
        isEditing = false
    }

    func saveEdits() async {
        guard canSave else { return }
        item.title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        item.itemDescription = draftDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        item.updatedAt = .now
        isEditing = false
        await commit(.update)
    }

    func toggleFavorite() async {
        item.isFavorite.toggle()
        item.updatedAt = .now
        await commit(.update)
    }

    func delete() async {
        item.isDeleted = true
        item.updatedAt = .now
        await commit(.delete)
    }

    func dismissError() { errorMessage = nil }

    private func commit(_ operation: SyncOperation) async {
        do {
            try syncService.enqueue(operation, for: item)
            try store.save()
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        if monitor.isConnected {
            await syncService.pushPendingChanges()
        }
    }
}
