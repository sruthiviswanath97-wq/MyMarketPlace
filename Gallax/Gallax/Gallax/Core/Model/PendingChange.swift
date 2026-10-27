//
//  PendingChange.swift
//  Gallax
//
//  Created by sruthi.e01 on 25/10/26.
//

import Foundation
import SwiftData


@Model
final class PendingChange {

    @Attribute(.unique) var id: UUID

    var itemLocalId: UUID

    var operationRaw: String

    var payloadData: Data?

    var clientUpdatedAt: Date

    var statusRaw: String
    var retryCount: Int
    var lastError: String?
    var createdAt: Date

    init(id: UUID = UUID(),
         itemLocalId: UUID,
         operation: SyncOperation,
         payload: ChangePayload? = nil,
         clientUpdatedAt: Date = .now,
         status: SyncStatus = .pending,
         retryCount: Int = 0,
         lastError: String? = nil,
         createdAt: Date = .now) {
        self.id = id
        self.itemLocalId = itemLocalId
        self.operationRaw = operation.rawValue
        self.payloadData = payload.flatMap { try? JSONEncoder().encode($0) }
        self.clientUpdatedAt = clientUpdatedAt
        self.statusRaw = status.rawValue
        self.retryCount = retryCount
        self.lastError = lastError
        self.createdAt = createdAt
    }

    var operation: SyncOperation {
        get { SyncOperation(rawValue: operationRaw) ?? .update }
        set { operationRaw = newValue.rawValue }
    }

    var status: SyncStatus {
        get { SyncStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var payload: ChangePayload? {
        guard let payloadData else { return nil }
        return try? JSONDecoder().decode(ChangePayload.self, from: payloadData)
    }
}

nonisolated struct ChangePayload: Codable, Equatable {
    var title: String
    var description: String
    var isFavorite: Bool
}
