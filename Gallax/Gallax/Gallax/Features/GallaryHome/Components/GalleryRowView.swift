//
//  GalleryRowView.swift
//  Gallax
//
//  Created by sruthi.e01 on 25/10/26.
//

import SwiftUI

struct GalleryRowView: View {

    let item: GalleryItem
    let onToggleFavorite: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {

            CachedImage(localData: item.thumbnailData ?? item.imageData,
                        remoteURL: item.imageURL,
                        cacheKey: item.localId.uuidString,
                        maxPixelSize: ImageDownsampler.thumbnailMaxPixel)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(item.itemDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 4)

            VStack(spacing: 12) {
                SyncStatusBadge(status: item.syncStatus)

                HStack(spacing: 14) {
                    Button(action: onToggleFavorite) {
                        Image(systemName: item.isFavorite ? "heart.fill" : "heart")
                            .foregroundStyle(item.isFavorite ? .pink : .secondary)
                    }
                    .accessibilityLabel(item.isFavorite ? "Remove from favorites" : "Add to favorites")

                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .accessibilityLabel("Delete item")
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}
