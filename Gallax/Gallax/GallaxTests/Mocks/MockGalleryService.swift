//
//  MockGalleryService.swift
//  GallaxTests
//
//  Created by sruthi.e01 on 25/10/26.
//

import Foundation
@testable import Gallax

final class MockGalleryService: GalleryServicing, @unchecked Sendable {

    var remoteItems: [RemoteItem] = []
    var shouldFail = false
    var failureError: Error = APIError.offline

    private(set) var fetchCallCount = 0
    private(set) var createCallCount = 0
    private(set) var updateCallCount = 0
    private(set) var deleteCallCount = 0
    private(set) var deletedIds: [String] = []
    private(set) var updatedTitles: [String] = []

    var nextCreatedId = "900"
    var stampedUpdatedAt: Date?

    func fetchItems(limit: Int) async throws -> [RemoteItem] {
        fetchCallCount += 1
        if shouldFail { throw failureError }
        return remoteItems
    }

    func createItem(title: String, description: String) async throws -> RemoteItem {
        createCallCount += 1
        if shouldFail { throw failureError }
        return RemoteItem(remoteId: nextCreatedId,
                          title: title,
                          description: description,
                          imageURL: nil,
                          updatedAt: stampedUpdatedAt ?? .now)
    }

    func updateItem(remoteId: String, title: String, description: String) async throws -> RemoteItem {
        updateCallCount += 1
        updatedTitles.append(title)
        if shouldFail { throw failureError }
        return RemoteItem(remoteId: remoteId,
                          title: title,
                          description: description,
                          imageURL: nil,
                          updatedAt: stampedUpdatedAt ?? .now)
    }

    func deleteItem(remoteId: String) async throws {
        deleteCallCount += 1
        if shouldFail { throw failureError }
        deletedIds.append(remoteId)
    }
}

final class MockNetworkMonitor: NetworkMonitoring {
    var isConnected: Bool
    init(isConnected: Bool = true) {
        self.isConnected = isConnected
    }
}
