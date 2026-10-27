//
//  SyncStatus.swift
//  Gallax
//
//  Created by sruthi.e01 on 25/10/26.
//

import Foundation

/// Lifecycle of a locally-originated change on its way to the server.
enum SyncStatus: String, Codable, CaseIterable {
    case pending
    case syncing
    case synced
    case failed

    var iconName: String {
        switch self {
        case .pending: return "clock.badge.exclamationmark"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .synced: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    var label: String {
        switch self {
        case .pending: return "Pending"
        case .syncing: return "Syncing"
        case .synced: return "Synced"
        case .failed: return "Failed"
        }
    }
}

/// The kind of mutation queued for replay against the server.
enum SyncOperation: String, Codable {
    case create
    case update
    case delete
}
