//
//  SyncServiceTests.swift
//  GallaxTests
//
//  Created by sruthi.e01 on 25/10/26.
//

import SwiftData
import XCTest
@testable import Gallax

@MainActor
final class SyncServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var store: GalleryDataStore!
    private var service: MockGalleryService!
    private var monitor: MockNetworkMonitor!
    private var sut: SyncService!

    override func setUp() async throws {
        try await super.setUp()
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: GalleryItem.self, PendingChange.self,
                                       configurations: configuration)
        store = GalleryDataStore(context: ModelContext(container))
        service = MockGalleryService()
        monitor = MockNetworkMonitor(isConnected: true)
        sut = SyncService(store: store, service: service, monitor: monitor)
    }

    override func tearDown() async throws {
        sut = nil
        store = nil
        container = nil
        service = nil
        monitor = nil
        try await super.tearDown()
    }

    private func makeItem(title: String = "Local item",
                          remoteId: String? = nil,
                          updatedAt: Date = .now) -> GalleryItem {
        let item = GalleryItem(remoteId: remoteId,
                               title: title,
                               itemDescription: "Description",
                               updatedAt: updatedAt)
        store.insert(item)
        return item
    }

    // MARK: - Queueing

    func testEnqueueCreate_writesPendingChangeAndMarksItemPending() throws {
        let item = makeItem()
        try sut.enqueue(.create, for: item)

        let pending = try store.fetchPendingChanges()
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending.first?.operation, .create)
        XCTAssertEqual(pending.first?.itemLocalId, item.localId)
        XCTAssertEqual(item.syncStatus, .pending)
    }

    func testQueuedChangeCarriesPayloadForReplay() throws {
        let item = makeItem(title: "Sunset")
        item.isFavorite = true
        try sut.enqueue(.update, for: item)

        let payload = try XCTUnwrap(try store.fetchPendingChanges().first?.payload)
        XCTAssertEqual(payload.title, "Sunset")
        XCTAssertTrue(payload.isFavorite)
    }

    // MARK: - Push

    func testPushCreate_whenOnline_assignsRemoteIdAndClearsQueue() async throws {
        let item = makeItem()
        try sut.enqueue(.create, for: item)
        service.nextCreatedId = "321"

        await sut.pushPendingChanges()

        XCTAssertEqual(service.createCallCount, 1)
        XCTAssertEqual(item.remoteId, "321")
        XCTAssertEqual(item.syncStatus, .synced)
        XCTAssertTrue(try store.fetchPendingChanges().isEmpty)
    }

    func testPushUpdate_sendsLatestLocalValues() async throws {
        let item = makeItem(title: "Before", remoteId: "12")
        try sut.enqueue(.update, for: item)
        item.title = "After"

        await sut.pushPendingChanges()

        XCTAssertEqual(service.updateCallCount, 1)
        XCTAssertEqual(service.updatedTitles, ["After"])
        XCTAssertEqual(item.syncStatus, .synced)
    }

    func testPushUpdate_whenItemNeverCreatedRemotely_promotesToCreate() async throws {
        let item = makeItem(remoteId: nil)
        try sut.enqueue(.update, for: item)

        await sut.pushPendingChanges()

        XCTAssertEqual(service.updateCallCount, 0)
        let change = try XCTUnwrap(try store.fetchPendingChanges().first)
        XCTAssertEqual(change.operation, .create)
    }

    func testPushDelete_removesItemLocallyAndRemotely() async throws {
        let item = makeItem(remoteId: "77")
        item.isDeleted = true
        try sut.enqueue(.delete, for: item)

        await sut.pushPendingChanges()

        XCTAssertEqual(service.deletedIds, ["77"])
        XCTAssertTrue(try store.fetchPendingChanges().isEmpty)
        XCTAssertNil(try store.fetchItem(localId: item.localId))
    }

    func testPushFailure_marksChangeFailedAndRetainsItInQueue() async throws {
        let item = makeItem()
        try sut.enqueue(.create, for: item)
        service.shouldFail = true

        await sut.pushPendingChanges()

        let change = try XCTUnwrap(try store.fetchPendingChanges().first)
        XCTAssertEqual(change.status, .failed)
        XCTAssertEqual(change.retryCount, 1)
        XCTAssertNotNil(change.lastError)
        XCTAssertEqual(item.syncStatus, .failed)
    }

    func testPushRetries_untilMaxRetryCountThenStops() async throws {
        let item = makeItem()
        try sut.enqueue(.create, for: item)
        service.shouldFail = true

        for _ in 0..<(SyncService.maxRetryCount + 3) {
            await sut.pushPendingChanges()
        }

        let change = try XCTUnwrap(try store.fetchPendingChanges().first)
        XCTAssertEqual(change.retryCount, SyncService.maxRetryCount)
        XCTAssertEqual(service.createCallCount, SyncService.maxRetryCount)
    }

    func testPushSkipped_whenOffline() async throws {
        let item = makeItem()
        try sut.enqueue(.create, for: item)
        monitor.isConnected = false

        await sut.pushPendingChanges()

        XCTAssertEqual(service.createCallCount, 0)
        XCTAssertEqual(try store.fetchPendingChanges().count, 1)
    }

    func testQueuedChangeSurvivesOfflineThenSyncsOnReconnect() async throws {
        monitor.isConnected = false
        let item = makeItem()
        try sut.enqueue(.create, for: item)
        await sut.pushPendingChanges()
        XCTAssertEqual(try store.fetchPendingChanges().count, 1)

        monitor.isConnected = true
        await sut.pushPendingChanges()

        XCTAssertEqual(service.createCallCount, 1)
        XCTAssertTrue(try store.fetchPendingChanges().isEmpty)
        XCTAssertEqual(item.syncStatus, .synced)
    }

    func testOverlappingDrains_doNotSubmitTheSameChangeTwice() async throws {
        let item = makeItem()
        try sut.enqueue(.create, for: item)

        // Two drains racing, exactly as a pull-to-refresh overlapping a
        // favourite toggle would produce.
        async let first: Void = sut.pushPendingChanges()
        async let second: Void = sut.pushPendingChanges()
        _ = await (first, second)

        XCTAssertEqual(service.createCallCount, 1)
        XCTAssertTrue(try store.fetchPendingChanges().isEmpty)
    }

    func testInterruptedSyncingChange_isRetriedRatherThanStranded() async throws {
        let item = makeItem()
        try sut.enqueue(.create, for: item)

        // Simulate the app being killed mid-push: the change is persisted
        // as `.syncing` and no longer matches `.pending`.
        let change = try XCTUnwrap(try store.fetchPendingChanges().first)
        change.status = .syncing
        try store.save()

        await sut.pushPendingChanges()

        XCTAssertEqual(service.createCallCount, 1)
        XCTAssertEqual(item.syncStatus, .synced)
        XCTAssertTrue(try store.fetchPendingChanges().isEmpty)
    }

    // MARK: - Simulated backend that never persists creates

    func testUpdate404_onLocallyCreatedItem_isTreatedAsSyncedAndNotRetried() async throws {
        let item = GalleryItem(title: "Local only",
                               itemDescription: "Description",
                               isLocallyCreated: true)
        store.insert(item)
        try sut.enqueue(.create, for: item)
        await sut.pushPendingChanges()
        XCTAssertEqual(item.syncStatus, .synced)

        // The mock backend forgets the record, so the follow-up edit 404s.
        service.shouldFail = true
        service.failureError = APIError.badStatus(404)
        item.title = "Edited offline-owned item"
        item.updatedAt = .now
        try sut.enqueue(.update, for: item)
        await sut.pushPendingChanges()

        XCTAssertEqual(item.syncStatus, .synced)
        XCTAssertEqual(item.remoteUpdatedAt, item.updatedAt)
        XCTAssertTrue(try store.fetchPendingChanges().isEmpty)
    }

    func testUpdate404_onServerOriginItem_stillReportsFailure() async throws {
        let item = makeItem(remoteId: "42")
        item.isLocallyCreated = false
        try sut.enqueue(.update, for: item)

        service.shouldFail = true
        service.failureError = APIError.badStatus(404)
        await sut.pushPendingChanges()

        XCTAssertEqual(item.syncStatus, .failed)
        XCTAssertEqual(try store.fetchPendingChanges().count, 1)
    }

    func testDelete404_isTreatedAsAlreadyDeleted() async throws {
        let item = makeItem(remoteId: "195")
        item.isLocallyCreated = true
        try sut.enqueue(.delete, for: item)

        service.shouldFail = true
        service.failureError = APIError.badStatus(404)
        await sut.pushPendingChanges()

        XCTAssertTrue(try store.fetchPendingChanges().isEmpty)
        XCTAssertTrue(try store.fetchItems().isEmpty)
    }

    // MARK: - Pull + conflict resolution

    func testPullInsertsUnknownRemoteItems() async throws {
        service.remoteItems = [
            RemoteItem(remoteId: "1", title: "Remote A", description: "A",
                       imageURL: "https://example.com/a.jpg", updatedAt: .now)
        ]

        try await sut.pullRemoteItems()

        let items = try store.fetchItems()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.remoteId, "1")
        XCTAssertEqual(items.first?.syncStatus, .synced)
    }

    func testPullWithNewerRemote_overwritesLocalFields() async throws {
        let old = Date(timeIntervalSince1970: 1_000_000)
        let item = makeItem(title: "Stale", remoteId: "5", updatedAt: old)
        try store.save()

        service.remoteItems = [
            RemoteItem(remoteId: "5", title: "Fresh", description: "Updated",
                       imageURL: nil, updatedAt: old.addingTimeInterval(500))
        ]

        try await sut.pullRemoteItems()

        XCTAssertEqual(item.title, "Fresh")
        XCTAssertEqual(item.itemDescription, "Updated")
        XCTAssertEqual(item.syncStatus, .synced)
    }

    func testPullDoesNotClobberNewerUnsyncedLocalEdit() async throws {
        let old = Date(timeIntervalSince1970: 1_000_000)
        let item = makeItem(title: "My offline edit",
                            remoteId: "5",
                            updatedAt: old.addingTimeInterval(900))
        try sut.enqueue(.update, for: item)

        service.remoteItems = [
            RemoteItem(remoteId: "5", title: "Server copy", description: "Server",
                       imageURL: nil, updatedAt: old)
        ]

        try await sut.pullRemoteItems()

        XCTAssertEqual(item.title, "My offline edit")
        XCTAssertEqual(item.syncStatus, .pending)
    }

    // MARK: - Full sync

    func testSync_pushesQueueThenPullsRemote() async throws {
        let item = makeItem()
        try sut.enqueue(.create, for: item)
        service.remoteItems = [
            RemoteItem(remoteId: "42", title: "Remote", description: "D",
                       imageURL: nil, updatedAt: .now)
        ]

        await sut.sync()

        XCTAssertEqual(service.createCallCount, 1)
        XCTAssertEqual(service.fetchCallCount, 1)
        XCTAssertEqual(sut.phase, .idle)
        XCTAssertNotNil(sut.lastSyncedAt)
    }

    func testSync_whenOffline_reportsFailedPhaseWithoutNetworkCalls() async {
        monitor.isConnected = false

        await sut.sync()

        XCTAssertEqual(sut.phase, .failed("Offline"))
        XCTAssertEqual(service.fetchCallCount, 0)
        XCTAssertEqual(service.createCallCount, 0)
    }
}
