//
//  GalleryServicing.swift
//  Gallax
//
//  Created by sruthi.e01 on 25/10/26.
//

import Foundation

/// Remote data source contract. Kept protocol-based so the sync engine can be
/// unit tested against a mock without touching the network.
protocol GalleryServicing: Sendable {
    func fetchItems(limit: Int) async throws -> [RemoteItem]
    func createItem(title: String, description: String) async throws -> RemoteItem
    func updateItem(remoteId: String, title: String, description: String) async throws -> RemoteItem
    func deleteItem(remoteId: String) async throws
}

extension GalleryServicing {
    func fetchItems() async throws -> [RemoteItem] {
        try await fetchItems(limit: 0)
    }
}
