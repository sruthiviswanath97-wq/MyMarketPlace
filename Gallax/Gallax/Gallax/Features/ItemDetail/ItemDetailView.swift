//
//  ItemDetailView.swift
//  Gallax
//
//  Created by sruthi.e01 on 25/10/26.
//

import SwiftUI
import SwiftData

struct ItemDetailView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(SyncService.self) private var syncService
    @Environment(\.dismiss) private var dismiss

    let item: GalleryItem
    @State private var viewModel: ItemDetailViewModel?

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = ItemDetailViewModel(item: item,
                                                modelContext: modelContext,
                                                syncService: syncService)
            }
        }
    }

    @ViewBuilder
    private func content(_ viewModel: ItemDetailViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                CachedImage(localData: item.imageData ?? item.thumbnailData,
                            remoteURL: item.imageURL,
                            cacheKey: item.localId.uuidString,
                            maxPixelSize: ImageDownsampler.detailMaxPixel)
                    .frame(height: 280)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                statusRow(viewModel)

                if viewModel.isEditing {
                    editor(viewModel)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(item.title)
                            .font(.title2.bold())
                        Text(item.itemDescription)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }

                metadata
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if viewModel.isEditing {
                    Button("Save") {
                        Task { await viewModel.saveEdits() }
                    }
                    .disabled(!viewModel.canSave)

                    Button("Cancel", role: .cancel) {
                        viewModel.cancelEditing()
                    }
                } else {
                    Button {
                        Task { await viewModel.toggleFavorite() }
                    } label: {
                        Image(systemName: item.isFavorite ? "heart.fill" : "heart")
                            .foregroundStyle(item.isFavorite ? .pink : .accentColor)
                    }
                    .accessibilityLabel(item.isFavorite ? "Remove from favorites" : "Add to favorites")

                    Button {
                        viewModel.beginEditing()
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .accessibilityLabel("Edit item")

                    Button(role: .destructive) {
                        Task {
                            await viewModel.delete()
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .accessibilityLabel("Delete item")
                }
            }
        }
        .alert("Something went wrong",
               isPresented: Binding(get: { viewModel.errorMessage != nil },
                                    set: { if !$0 { viewModel.dismissError() } })) {
            Button("OK", role: .cancel) { viewModel.dismissError() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private func statusRow(_ viewModel: ItemDetailViewModel) -> some View {
        HStack(spacing: 12) {
            SyncStatusBadge(status: item.syncStatus, showsLabel: true)

            if item.isFavorite {
                Label("Favorite", systemImage: "heart.fill")
                    .font(.caption2)
                    .foregroundStyle(.pink)
            }

            Spacer()

            HStack(spacing: 5) {
                Circle()
                    .fill(viewModel.isConnected ? .green : .red)
                    .frame(width: 7, height: 7)
                Text(viewModel.isConnected ? "Online" : "Offline")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func editor(_ viewModel: ItemDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Title")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Title", text: Binding(get: { viewModel.draftTitle },
                                                 set: { viewModel.draftTitle = $0 }))
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Description")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Description",
                          text: Binding(get: { viewModel.draftDescription },
                                        set: { viewModel.draftDescription = $0 }),
                          axis: .vertical)
                    .lineLimit(3...8)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 8) {
            labelled("Item ID", item.remoteId ?? "Not synced yet")
            labelled("Last edited", item.updatedAt.formatted(date: .abbreviated, time: .shortened))
            if let remoteUpdatedAt = item.remoteUpdatedAt {
                labelled("Server version",
                         remoteUpdatedAt.formatted(date: .abbreviated, time: .shortened))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func labelled(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.medium))
        }
    }
}
