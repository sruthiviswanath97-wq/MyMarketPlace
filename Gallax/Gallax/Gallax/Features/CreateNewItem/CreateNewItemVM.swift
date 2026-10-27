//
//  CreateNewItemVM.swift
//  Gallax
//
//  Created by sruthi.e01 on 25/10/26.
//

import Foundation
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

@MainActor
@Observable
final class CreateNewItemVM {

    var title: String = ""
    var itemDescription: String = ""
    var selectedItem: PhotosPickerItem?
    private(set) var previewImage: UIImage?
    private(set) var isSaving = false
    private(set) var errorMessage: String?

    @ObservationIgnored private var fullImageData: Data?
    @ObservationIgnored private var thumbnailData: Data?
    @ObservationIgnored private var store: GalleryDataStore?
    @ObservationIgnored private var syncService: SyncService?
    @ObservationIgnored private let monitor: NetworkMonitor

   
    init(monitor: NetworkMonitor? = nil) {
        self.monitor = monitor ?? .shared
    }

    var isConnected: Bool { monitor.isConnected }


    var isFormValid: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = itemDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedTitle.isEmpty && trimmedTitle.count <= 120
            && !trimmedDescription.isEmpty && trimmedDescription.count <= 1000
            && fullImageData != nil
    }

    func configure(modelContext: ModelContext, syncService: SyncService) {
        guard store == nil else { return }
        self.store = GalleryDataStore(context: modelContext)
        self.syncService = syncService
    }

    func loadImage(from pickerItem: PhotosPickerItem?) async {
        guard let pickerItem else { return }
        do {
            guard let data = try await pickerItem.loadTransferable(type: Data.self) else {
                errorMessage = "That image could not be read."
                return
            }
            applyPickedImage(data: data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func applyPickedImage(data: Data) {

        let detail = ImageDownsampler.downsample(data: data,
                                                 maxPixelSize: ImageDownsampler.detailMaxPixel)
        fullImageData = detail?.jpegData(compressionQuality: 0.8) ?? data
        thumbnailData = ImageDownsampler.thumbnailData(from: data)
        previewImage = detail ?? UIImage(data: data)
    }

    func save() async -> Bool {
        guard isFormValid, let store, let syncService else { return false }
        isSaving = true
        defer { isSaving = false }

        let item = GalleryItem(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            itemDescription: itemDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            imageData: fullImageData,
            thumbnailData: thumbnailData,
            updatedAt: .now,
            syncStatus: .pending,
            isLocallyCreated: true
        )

        do {
            store.insert(item)
            try syncService.enqueue(.create, for: item)
        } catch {
            errorMessage = error.localizedDescription
            return false
        }

        if monitor.isConnected {
            await syncService.pushPendingChanges()
        }
        return true
    }

    func dismissError() { errorMessage = nil }
}
