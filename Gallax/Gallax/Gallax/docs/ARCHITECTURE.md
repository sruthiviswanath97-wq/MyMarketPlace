# Architecture

Gallax follows **MVVM + DataStore + Protocol-Oriented Dependency Injection**, built on
SwiftUI, SwiftData and Swift Concurrency. It is an **offline-first** app: the local database
is the single source of truth, and the network is treated as a background reconciliation
detail rather than something the UI waits on.

---

## Architecture Overview

```text
                    ┌──────────────────┐
                    │   SwiftUI View   │
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │    ViewModel     │   @Observable
                    └────────┬─────────┘
                             │
                 ┌───────────┴───────────┐
                 ▼                       ▼
        ┌──────────────────┐    ┌──────────────────┐
        │ GalleryDataStore │    │   SyncService    │◄── NetworkMonitor
        └────────┬─────────┘    └────────┬─────────┘
                 │                       │
                 ▼                       ▼
        ┌──────────────────┐    ┌──────────────────┐
        │     SwiftData    │    │ProductAPIService │
        └──────────────────┘    └────────┬─────────┘
                                         │
                                         ▼
                                ┌──────────────────┐
                                │   dummyjson.com  │
                                └──────────────────┘
```

The View never touches the network or the database directly. The ViewModel never
constructs its own dependencies — they are injected from `GallaxApp`.

---

## Layers

| Layer | Type | Responsibility |
|---|---|---|
| **View** | SwiftUI `View` | Rendering and user intent only. No business logic. |
| **ViewModel** | `@Observable` class | Derives display state, forwards actions, owns no storage. |
| **DataStore** | `GalleryDataStoring` | The only code that talks to SwiftData. |
| **SyncService** | `SyncServicing` | Owns the offline queue, conflict resolution, retries. |
| **APIService** | `GalleryServicing` | REST calls, DTO decoding. Knows nothing about the DB. |
| **Monitor** | `NetworkMonitoring` | Connectivity state + reconnect callback. |
| **Imaging** | `ImageLoader` / `ImageCache` | Download, downsample, two-tier cache. |

Each boundary is a protocol, so every layer can be replaced with a mock in tests.

---

## 1. Data Flow

### Reading the gallery

The list always renders from the local database. A cold launch with no network still
shows content.

```text
                             View
                              ↓
                          ViewModel
                              ↓
                       GalleryDataStore
                              ↓
                          SwiftData
```

### Refreshing from the API

```text
                          SyncService
                              ↓
                      ProductAPIService
                              ↓
                          REST API
                              ↓
                         ProductDTO
                              ↓
                      ConflictResolver        ← last-write-wins
                              ↓
                        GalleryItem
                              ↓
                          SwiftData
                              ↓
                          ViewModel
                              ↓
                             View
```

### Creating or editing offline

The write lands in SwiftData **immediately** and a `PendingChange` is queued alongside it.
The UI updates at once; the network catches up later.

```text
                             User
                              ↓
                          ViewModel
                              ↓
                       GalleryDataStore
                              ↓
                   GalleryItem + PendingChange     ← both saved locally
                              ↓
                      [ app may close here ]
                              ↓
                         SyncService
                              ↓
                      ProductAPIService
                              ↓
                          REST API
```

---

## 2. Offline Queue

`PendingChange` is a SwiftData model, not an in-memory array, so the queue survives
force-quit and reboot.

| Field | Purpose |
|---|---|
| `operation` | `create` / `update` / `delete` |
| `itemLocalId` | Links back to the `GalleryItem` |
| `payload` | Snapshot of the change for replay |
| `statusRaw` | `pending` / `syncing` / `synced` / `failed` |
| `retryCount` | Capped at 5, then the change stops retrying |
| `createdAt` | Drains in FIFO order |

### Drain sequence

```text
              pushPendingChanges()
                       ↓
          isDraining guard  ─── already running? → return
                       ↓
          reset stale .syncing → .pending        ← crash recovery
                       ↓
          fetch changes, oldest first
                       ↓
             ┌─────────┴─────────┐
             ▼                   ▼
          success              failure
             ↓                   ↓
      delete change      retryCount += 1
      mark item synced   status = .failed
```

**Single shared instance.** `GallaxApp` builds exactly one `SyncService` and injects it
with `.environment(...)`. Three view models each creating their own would mean three
independent drain guards, which could submit the same change twice.

**Crash recovery.** A change interrupted mid-flight stays `.syncing` on disk forever.
Resetting `.syncing → .pending` at the start of each drain is safe because nothing can
legitimately be in flight at that moment.

---

## 3. Conflict Resolution

`ConflictResolver` is a pure function — no I/O, no state — which makes the policy trivial
to unit test.

```text
         local.updatedAt   vs   remote.updatedAt
                       ↓
          ┌────────────┼────────────┐
          ▼            ▼            ▼
      useRemote    keepLocal     noChange
```

| Situation | Outcome |
|---|---|
| Remote is newer | `useRemote` — overwrite local fields |
| Local is newer, changes queued | `keepLocal` — the queue will push it |
| Timestamps identical | `keepLocal` — never clobber a same-second edit |
| Remote timestamp missing | Falls back to local |

**Last-write-wins**, decided by timestamp rather than arrival order.

---

## 4. Network Monitoring

`NetworkMonitor` wraps `NWPathMonitor` and exposes `isConnected` for the status pill.

```text
          NWPathMonitor path becomes satisfied
                          ↓
                    onReconnect()
                          ↓
                 SyncService.sync()
                          ↓
              queue drains automatically
```

This callback is what makes the queue genuinely background: the user does not pull to
refresh, and does not need the app in the foreground at the moment connectivity returns.

---

## 5. Image Caching

Two tiers, with downsampling in front of both so a full-resolution bitmap is never
retained.

```text
                        CachedImage
                             ↓
                        ImageLoader
                             ↓
                      Memory (NSCache)  ── hit → return
                             ↓ miss
                      Disk (SHA256 .jpg) ── hit → return
                             ↓ miss
                          Network
                             ↓
                      ImageDownsampler    ← ImageIO, decodes to target size
                             ↓
                   store in memory + disk
```

| Component | Detail |
|---|---|
| **ImageDownsampler** | `CGImageSourceCreateThumbnailAtIndex` decodes *directly* at the target size. A 4000×3000 photo never exists as a ~48 MB bitmap. 300 px for rows, 1200 px for detail. |
| **ImageCache** | `NSCache` at 150 items / 40 MB, cost measured in decoded bytes. Disk files named by SHA256 of the key. |
| **ImageLoader** | Cache lookup → download → downsample → store. Keys include pixel size, so thumbnail and detail versions coexist. |

---

## 6. Dependency Injection

`GallaxApp` is the composition root. It builds one `ModelContainer` and one `SyncService`,
then passes them down the view tree.

```text
GallaxApp
 ├── ModelContainer ........ GalleryItem, PendingChange
 └── SyncService ........... shared, injected via .environment
      ├── GalleryDataStore . SwiftData access
      ├── ProductAPIService  REST
      └── NetworkMonitor ... NWPathMonitor
```

View models receive their dependencies through `configure(modelContext:syncService:)`
rather than constructing them, which is what allows tests to substitute mocks.

---

## 7. Testing

Protocol-based dependencies allow mock implementations:

```text
MockGalleryService      ← scripted API responses and failures
MockNetworkMonitor      ← simulates offline / online
in-memory ModelContainer ← real SwiftData, no disk
```

| Suite | Count | Covers |
|---|---|---|
| `SyncServiceTests` | 20 | Queueing, drain, retries, 404 handling, concurrency, crash recovery |
| `ConflictResolverTests` | 7 | Every branch of the last-write-wins policy |
| `ImageDownsamplerTests` | 4 | Pixel reduction, aspect ratio, invalid data |

**31 tests total.** Sync is tested against a real in-memory SwiftData container, so the
tests exercise genuine persistence rather than a stubbed store.

---

## Design Decisions

| Decision | Reasoning |
|---|---|
| Local DB as source of truth | The UI never blocks on the network; offline is the default case, not an error path. |
| Queue in SwiftData, not memory | A queue that dies with the process is not an offline queue. |
| One shared `SyncService` | Serialises the drain app-wide; prevents duplicate submissions. |
| `ConflictResolver` as a pure function | Policy is testable in isolation from I/O. |
| Downsample before caching | Caps memory at the decode step, which is where it is actually spent. |
| Protocols at every boundary | Mocks in tests; layers stay swappable. |

### Known constraint

dummyjson is a **read-only mock**. `POST /products/add` returns a synthetic id but never
persists the record, so a follow-up `PUT` to that id returns 404. Items created on-device
are flagged `isLocallyCreated`, and a 404 on those is treated as success rather than
retried forever.
