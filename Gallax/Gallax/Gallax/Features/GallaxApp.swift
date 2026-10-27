//
//  GallaxApp.swift
//  Gallax
//
//  Created by sruthi.e01 on 21/10/26.
//

import SwiftUI
import SwiftData

@main
struct GallaxApp: App {

    private let container: ModelContainer
    @State private var syncService: SyncService

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(for: GalleryItem.self, PendingChange.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        self.container = container
        let store = GalleryDataStore(context: container.mainContext)
        _syncService = State(initialValue: SyncService(store: store,
                                                       service: ProductAPIService(),
                                                       monitor: NetworkMonitor.shared))
    }

    var body: some Scene {
        WindowGroup {
            GallaryView()
                .environment(syncService)
        }
        .modelContainer(container)
    }
}
