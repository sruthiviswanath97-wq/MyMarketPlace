//
//  ConflictResolverTests.swift
//  GallaxTests
//
//  Created by sruthi.e01 on 25/10/26.
//

import XCTest
@testable import Gallax

final class ConflictResolverTests: XCTestCase {

    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    func testRemoteNewerWithNoPendingChanges_usesRemote() {
        let resolution = ConflictResolver.resolve(
            localUpdatedAt: base,
            remoteUpdatedAt: base.addingTimeInterval(60),
            hasPendingLocalChanges: false
        )
        XCTAssertEqual(resolution, .useRemote)
    }

    func testLocalNewerWithPendingChanges_keepsLocal() {
        let resolution = ConflictResolver.resolve(
            localUpdatedAt: base.addingTimeInterval(60),
            remoteUpdatedAt: base,
            hasPendingLocalChanges: true
        )
        XCTAssertEqual(resolution, .keepLocal)
    }

    func testRemoteNewerWithPendingChanges_remoteStillWinsUnderLastWriteWins() {
        let resolution = ConflictResolver.resolve(
            localUpdatedAt: base,
            remoteUpdatedAt: base.addingTimeInterval(60),
            hasPendingLocalChanges: true
        )
        XCTAssertEqual(resolution, .useRemote)
    }

    func testLocalNewerWithoutPendingChanges_isNoChange() {
        let resolution = ConflictResolver.resolve(
            localUpdatedAt: base.addingTimeInterval(60),
            remoteUpdatedAt: base,
            hasPendingLocalChanges: false
        )
        XCTAssertEqual(resolution, .noChange)
    }

    func testMissingRemoteTimestampWithPendingChanges_keepsLocal() {
        let resolution = ConflictResolver.resolve(
            localUpdatedAt: base,
            remoteUpdatedAt: nil,
            hasPendingLocalChanges: true
        )
        XCTAssertEqual(resolution, .keepLocal)
    }

    func testMissingRemoteTimestampWithoutPendingChanges_isNoChange() {
        let resolution = ConflictResolver.resolve(
            localUpdatedAt: base,
            remoteUpdatedAt: nil,
            hasPendingLocalChanges: false
        )
        XCTAssertEqual(resolution, .noChange)
    }

    func testIdenticalTimestamps_doNotOverwriteLocal() {
        let resolution = ConflictResolver.resolve(
            localUpdatedAt: base,
            remoteUpdatedAt: base,
            hasPendingLocalChanges: true
        )
        XCTAssertEqual(resolution, .keepLocal)
    }
}
