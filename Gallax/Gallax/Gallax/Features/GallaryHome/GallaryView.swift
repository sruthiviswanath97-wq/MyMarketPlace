//
//  GallaryView.swift
//  Gallax
//
//  Created by sruthi.e01 on 25/10/26.
//

import SwiftUI
import SwiftData

struct GallaryView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(SyncService.self) private var syncService
    @State private var viewModel = GallaryViewModel()
    @State private var showCreateView = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    GalleryHeaderView(totalCount: viewModel.totalCount,
                                      syncedCount: viewModel.syncedCount,
                                      unsyncedCount: viewModel.unsyncedCount,
                                      favoriteCount: viewModel.favoriteCount,
                                      isConnected: viewModel.isConnected,
                                      connectionLabel: viewModel.connectionLabel,
                                      syncPhase: viewModel.syncPhase,
                                      lastSyncedAt: viewModel.lastSyncedAt)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }

                Section {
                    ForEach(viewModel.items, id: \.localId) { item in
                        NavigationLink {
                            ItemDetailView(item: item)
                                .onDisappear { viewModel.reload() }
                        } label: {
                            GalleryRowView(
                                item: item,
                                onToggleFavorite: { viewModel.toggleFavorite(item) },
                                onDelete: { viewModel.delete(item) }
                            )
                        }
                    }
                } header: {
                    if !viewModel.items.isEmpty {
                        Text("Product List")
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Marketplace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateView = true
                    } label: {
                        Label("Add Photo", systemImage: "plus.circle.fill")
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .overlay {
                if viewModel.items.isEmpty {
                    ContentUnavailableView(
                        "No items yet",
                        systemImage: "photo.on.rectangle.angled",
                        description: Text(viewModel.isConnected
                                          ? "Pull to refresh or add your first photo."
                                          : "You're offline. Added items will sync automatically.")
                    )
                }
            }
            .fullScreenCover(isPresented: $showCreateView, onDismiss: {
                viewModel.reload()
            }) {
                CreateNewItemView(showCreateView: $showCreateView)
            }
            .alert("Something went wrong",
                   isPresented: Binding(get: { viewModel.errorMessage != nil },
                                        set: { if !$0 { viewModel.dismissError() } })) {
                Button("OK", role: .cancel) { viewModel.dismissError() }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .task {
                viewModel.configure(modelContext: modelContext, syncService: syncService)
                await viewModel.refresh()
            }
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: GalleryItem.self, PendingChange.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let syncService = SyncService(store: GalleryDataStore(context: container.mainContext),
                                  service: ProductAPIService(),
                                  monitor: NetworkMonitor.shared)
    return GallaryView()
        .modelContainer(container)
        .environment(syncService)
}
