//
//  SyncStatusBadge.swift
//  Gallax
//
//  Created by sruthi.e01 on 25/10/26.
//

import SwiftUI

struct SyncStatusBadge: View {

    let status: SyncStatus
    var showsLabel: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.iconName)
                .symbolEffect(.pulse, isActive: status == .syncing)
            if showsLabel {
                Text(status.label)
                    .font(.caption2)
            }
        }
        .foregroundStyle(tint)
        .accessibilityLabel("Sync status: \(status.label)")
    }

    private var tint: Color {
        switch status {
        case .synced: return .green
        case .pending: return .orange
        case .syncing: return .blue
        case .failed: return .red
        }
    }
}
