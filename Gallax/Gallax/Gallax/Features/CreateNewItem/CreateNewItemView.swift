//
//  CreateNewItemView.swift
//  Gallax
//
//  Created by sruthi.e01 on 21/10/26.
//

import SwiftUI
import SwiftData
import PhotosUI

struct CreateNewItemView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(SyncService.self) private var syncService
    @State private var viewModel = CreateNewItemVM()
    @Binding var showCreateView: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    imagePicker
                    detailsSection
                    if !viewModel.isConnected {
                        offlineNotice
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Add New product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showCreateView = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            if await viewModel.save() {
                                showCreateView = false
                            }
                        }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("Save").fontWeight(.semibold)
                        }
                    }
                    .disabled(!viewModel.isFormValid || viewModel.isSaving)
                }
            }
            .onChange(of: viewModel.selectedItem) { _, newValue in
                Task { await viewModel.loadImage(from: newValue) }
            }
            .onAppear {
                viewModel.configure(modelContext: modelContext, syncService: syncService)
            }
            .alert("Something went wrong",
                   isPresented: Binding(get: { viewModel.errorMessage != nil },
                                        set: { if !$0 { viewModel.dismissError() } })) {
                Button("OK", role: .cancel) { viewModel.dismissError() }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var imagePicker: some View {
        let preview = viewModel.previewImage

        return PhotosPicker(selection: $viewModel.selectedItem, matching: .images) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.accentColor.opacity(0.08))

                if let image = preview {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 260)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 45))
                        Text("Tap to Select an Image")
                            .font(.headline)
                        Text("Choose a photo from your library")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 260)
        }
    }

    private var detailsSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Title")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Enter title", text: $viewModel.title)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Enter description",
                          text: $viewModel.itemDescription,
                          axis: .vertical)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
    }

    private var offlineNotice: some View {
        Label("You're offline. This item will be saved locally and uploaded automatically.",
              systemImage: "icloud.slash")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.orange.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
