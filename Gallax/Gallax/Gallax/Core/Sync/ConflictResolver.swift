//
//  ConflictResolver.swift
//  Gallax
//
//  Created by sruthi.e01 on 25/10/26.
//

import Foundation

enum ConflictResolution: Equatable {
    case useRemote
    case keepLocal
    case noChange
}

enum ConflictResolver {
    static func resolve(localUpdatedAt: Date,
                        remoteUpdatedAt: Date?,
                        hasPendingLocalChanges: Bool) -> ConflictResolution {

        guard let remoteUpdatedAt else {
            return hasPendingLocalChanges ? .keepLocal : .noChange
        }

        if hasPendingLocalChanges {
            return remoteUpdatedAt > localUpdatedAt ? .useRemote : .keepLocal
        }

        return remoteUpdatedAt > localUpdatedAt ? .useRemote : .noChange
    }
}
