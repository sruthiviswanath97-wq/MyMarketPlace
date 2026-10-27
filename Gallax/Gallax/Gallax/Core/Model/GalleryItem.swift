//
//  GalleryItem.swift
//  Gallax
//
//  Created by sruthi.e01 on 25/10/26.
//

import Foundation
import SwiftData

@Model
final class GalleryItem {

    @Attribute(.unique) var localId: UUID

    var remoteId: String?

    var title: String
    var itemDescription: String

    @Attribute(.externalStorage) var imageData: Data?

    @Attribute(.externalStorage) var thumbnailData: Data?

    var imageURL: String?

    var isFavorite: Bool

    var updatedAt: Date

    var remoteUpdatedAt: Date?

    var syncStatusRaw: String

    var isDeleted: Bool

    var isLocallyCreated: Bool = false

    init(localId: UUID = UUID(),
         remoteId: String? = nil,
         title: String,
         itemDescription: String,
         imageData: Data? = nil,
         thumbnailData: Data? = nil,
         imageURL: String? = nil,
         isFavorite: Bool = false,
         updatedAt: Date = .now,
         remoteUpdatedAt: Date? = nil,
         syncStatus: SyncStatus = .pending,
         isDeleted: Bool = false,
         isLocallyCreated: Bool = false) {
        self.localId = localId
        self.remoteId = remoteId
        self.title = title
        self.itemDescription = itemDescription
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.imageURL = imageURL
        self.isFavorite = isFavorite
        self.updatedAt = updatedAt
        self.remoteUpdatedAt = remoteUpdatedAt
        self.syncStatusRaw = syncStatus.rawValue
        self.isDeleted = isDeleted
        self.isLocallyCreated = isLocallyCreated
    }

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .pending }
        set { syncStatusRaw = newValue.rawValue }
    }
}
