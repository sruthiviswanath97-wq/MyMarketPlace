//
//  GalleryHeaderView.swift
//  Gallax
//
//  Created by sruthi.e01 on 25/10/26.
//

import SwiftUI

struct GalleryHeaderView: View {

    let totalCount: Int
    let syncedCount: Int
    let unsyncedCount: Int
    let favoriteCount: Int
    let isConnected: Bool
    let connectionLabel: String
    let syncPhase: SyncService.Phase
    let lastSyncedAt: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Available Products")
                        .font(.default.bold())
                    Text("\(totalCount) products")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                connectionPill
            }

            HStack(spacing: 10) {
                statChip(value: syncedCount,
                         label: "Synced",
                         systemImage: "checkmark.circle.fill",
                         tint: .green)
                statChip(value: unsyncedCount,
                         label: "Pending",
                         systemImage: "clock.badge.exclamationmark",
                         tint: unsyncedCount > 0 ? .orange : .secondary)
                statChip(value: favoriteCount,
                         label: "Favorites",
                         systemImage: "heart.fill",
                         tint: .pink)
            }

            if let statusLine {
                Text(statusLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var connectionPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isConnected ? .green : .red)
                .frame(width: 8, height: 8)
            Text(connectionLabel)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background((isConnected ? Color.green : Color.red).opacity(0.12))
        .clipShape(Capsule())
        .accessibilityLabel("Network status: \(connectionLabel)")
    }

    private var statusLine: String? {
        switch syncPhase {
        case .syncing:
            return "Syncing…"
        case .failed(let message):
            return isConnected ? "Sync failed: \(message)" : "Offline — \(unsyncedCount) change(s) queued"
        case .idle:
            guard let lastSyncedAt else { return nil }
            return "Last synced \(lastSyncedAt.formatted(date: .omitted, time: .shortened))"
        }
    }

    private func statChip(value: Int,
                          label: String,
                          systemImage: String,
                          tint: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.caption)
                Text("\(value)")
                    .font(.headline)
            }
            .foregroundStyle(tint)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
