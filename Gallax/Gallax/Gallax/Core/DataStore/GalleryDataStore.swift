//
//  GalleryDataStore.swift
//  Gallax
//
//  Created by sruthi.e01 on 25/10/26.
//

import Foundation
import SwiftData

protocol GalleryDataStoring: AnyObject {
    func fetchItems() throws -> [GalleryItem]
    func fetchItem(localId: UUID) throws -> GalleryItem?
    func fetchPendingChanges() throws -> [PendingChange]
    func pendingChangeCount(forItem localId: UUID) throws -> Int
    func insert(_ item: GalleryItem)
    func insert(_ change: PendingChange)
    func delete(_ item: GalleryItem)
    func delete(_ change: PendingChange)
    func save() throws
}

/// Thin persistence boundary over SwiftData. Keeping it behind a protocol lets
/// the sync engine be tested with an in-memory container.
@MainActor
final class GalleryDataStore: GalleryDataStoring {

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchItems() throws -> [GalleryItem] {
        var descriptor = FetchDescriptor<GalleryItem>(
            predicate: #Predicate { $0.isDeleted == false },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = nil
        return try context.fetch(descriptor)
    }

    func fetchItem(localId: UUID) throws -> GalleryItem? {
        var descriptor = FetchDescriptor<GalleryItem>(
            predicate: #Predicate { $0.localId == localId }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func fetchPendingChanges() throws -> [PendingChange] {
        let synced = SyncStatus.synced.rawValue
        let descriptor = FetchDescriptor<PendingChange>(
            predicate: #Predicate { $0.statusRaw != synced },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    func pendingChangeCount(forItem localId: UUID) throws -> Int {
        let synced = SyncStatus.synced.rawValue
        let descriptor = FetchDescriptor<PendingChange>(
            predicate: #Predicate { $0.itemLocalId == localId && $0.statusRaw != synced }
        )
        return try context.fetchCount(descriptor)
    }

    func insert(_ item: GalleryItem) { context.insert(item) }
    func insert(_ change: PendingChange) { context.insert(change) }
    func delete(_ item: GalleryItem) { context.delete(item) }
    func delete(_ change: PendingChange) { context.delete(change) }

    func save() throws {
        guard context.hasChanges else { return }
        try context.save()
    }
}
