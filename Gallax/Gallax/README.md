# 🖼️ Gallax

An **offline-first gallery application** built with SwiftUI, SwiftData, Swift Concurrency, and MVVM architecture.

The application allows users to browse a product gallery, view item details, add items with photos, manage favorites, and automatically synchronize every offline create, edit, and delete the moment connectivity returns.

---

## ✨ Features

- 🖼️ Gallery listing and item detail screens
- ➕ Add new items with a photo picker
- ✏️ Inline editing of title and description
- ❤️ Favorite / unfavorite items
- 🗑️ Delete with soft-delete that survives offline
- 💾 Full local persistence using SwiftData
- 📬 Durable offline queue for create / update / delete
- ⚖️ Last-write-wins conflict resolution
- 📊 Live sync status — synced, pending, and favorite counts
- 🌐 Network availability monitoring with auto-sync on reconnect
- ⚡ Two-tier image caching (memory + disk)
- 📉 ImageIO thumbnail downsampling to cap memory usage
- 🧪 31 unit tests with mock dependencies

---

## 🛠 Tech Stack

| Technology | Usage |
|---|---|
| **Swift** | Primary language |
| **SwiftUI** | User interface |
| **SwiftData** | Local persistence |
| **Swift Concurrency** | Async operations, actors |
| **Observation** | `@Observable` view models |
| **REST API** | Remote data via dummyjson.com |
| **NWPathMonitor** | Connectivity monitoring |
| **ImageIO** | Thumbnail downsampling |
| **NSCache** | In-memory image caching |
| **CryptoKit** | SHA256 disk cache keys |
| **PhotosUI** | Item image selection |
| **XCTest** | Unit testing |

No third-party dependencies — Apple frameworks only.

---

## 🏗️ Architecture

The application follows:

**MVVM + Protocol-Oriented Dependency Injection**

> 📐 A detailed breakdown of layers, data flow and design decisions lives in
> [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md).

```text
SwiftUI View
     ↓
ViewModel
   ↙     ↘
DataStore  SyncService
   ↓        ↙      ↘
SwiftData  Queue  NetworkService
                      ↓
                   REST API
```

A **single `SyncService`** is created in `GallaxApp` and injected through the SwiftUI
environment, so the entire app shares one offline queue and one drain guard.

Every dependency sits behind a protocol, which is what makes the sync engine fully testable:

| Protocol | Implementation | Test double |
|---|---|---|
| `GalleryServicing` | `ProductAPIService` | `MockGalleryService` |
| `NetworkMonitoring` | `NetworkMonitor` | `MockNetworkMonitor` |
| `GalleryDataStoring` | `GalleryDataStore` | In-memory `ModelContainer` |

---

## 📂 Project Structure

```text
Gallax/
├── Core/
│   ├── Model/          GalleryItem, PendingChange, SyncStatus
│   ├── Services/       GalleryServicing, ProductAPIService, DTOs
│   ├── DataStore/      GalleryDataStore
│   ├── Sync/           SyncService, ConflictResolver
│   ├── Imaging/        ImageCache, ImageLoader, ImageDownsampler
│   ├── Monitoring/     NetworkMonitor
│   └── UI/             CachedImage, SyncStatusBadge
└── Features/
    ├── GallaryHome/    Home screen + header/row components
    ├── ItemDetail/     Detail screen
    └── CreateNewItem/  Add-item screen
```

---

## 🔄 Offline Sync

Every mutation is written to a durable queue in the **same SwiftData save** as the local
model change, so a change can never be lost if the app is killed before it reaches the server.

```text
User action
    │
    ├─► mutate GalleryItem locally   ┐
    │                                ├─ one atomic save
    └─► insert PendingChange         ┘
              │
              ▼
        online? ──no──► stays queued, UI shows "Pending"
           │
          yes
           ▼
   SyncService.pushPendingChanges()
           │
           ├─ ✅ success ──► item synced, change removed from queue
           └─ ❌ failure ──► retryCount += 1, change retained for replay
```

| Behaviour | Detail |
|---|---|
| 🗑️ **Soft delete** | `isDeleted = true` hides the row instantly while the delete survives to be replayed |
| ⬆️ **Update→create promotion** | An `.update` queued for an item never created remotely is rewritten as a `.create` |
| 🔁 **Retry cap** | Changes stop after `maxRetryCount = 5` instead of retrying forever |
| 🔒 **Serialised drains** | `pushPendingChanges()` is reentrancy-guarded, so overlapping syncs can't submit a change twice |
| 💥 **Crash recovery** | A change left as `.syncing` by a mid-push kill is reset to `.pending` and retried |

---

## ⚖️ Conflict Resolution

`ConflictResolver` is a pure function — no SwiftData, no networking — which makes it
directly unit-testable. It implements **last-write-wins** on timestamps:

| Local state | Remote timestamp | Resolution |
|---|---|---|
| Has queued changes | Newer than local | `.useRemote` — true LWW, remote wins |
| Has queued changes | Older or equal | `.keepLocal` — local is re-pushed |
| Has queued changes | Missing | `.keepLocal` — never discard pending work |
| Clean | Newer than local | `.useRemote` |
| Clean | Older or equal | `.noChange` |

Identical timestamps resolve to `.keepLocal`, so a same-second edit is never clobbered.

---

## ⚡ Image Caching & Thumbnails

```text
URL / local Data
      ↓
ImageLoader            cache lookup, then download
      ↓
ImageDownsampler       ImageIO decode straight to target size
      ↓
ImageCache             NSCache (memory) + SHA256 disk files
      ↓
CachedImage (SwiftUI)
```

| Component | Role |
|---|---|
| **ImageDownsampler** | `CGImageSourceCreateThumbnailAtIndex` decodes *directly* to the target size, so a 4000×3000 photo never occupies ~48 MB as a full bitmap. Uses 300 px for rows, 1200 px for detail. |
| **ImageCache** | `NSCache` capped at 150 items / 40 MB, costed by decoded byte footprint. Disk tier in `Caches/GallaxImageCache`, keyed by SHA256 of the cache key. |
| **ImageLoader** | Checks the cache first, downloads on a miss, downsamples, then writes both tiers. Cache keys include the pixel size so thumbnail and detail versions coexist. |

---

## 🌐 Network Monitoring

`NetworkMonitor` wraps `NWPathMonitor` and publishes `isConnected` / `isExpensive` for the
status pill. Its `onReconnect` callback is what turns the queue into true background sync —
the instant the path becomes satisfied, the home view model kicks off a full sync.

---

## 📱 Screens

| Screen | Contents |
|---|---|
| 🏠 **Home** | Title, total count, live connectivity pill, synced / pending / favorite counts, and a list of rows with cached thumbnail, title, favorite toggle, delete button, and sync badge |
| 🔍 **Detail** | Large 1200 px image, inline title and description editing, favorite and delete actions |
| ➕ **Create** | Photo picker with validation — non-empty title ≤ 120 chars, non-empty description ≤ 1000 chars, image required |

---

## 🧪 Testing

| Suite | Tests | Covers |
|---|---|---|
| `SyncServiceTests` | 20 | Queueing, push success/failure, retry cap, offline skip, update→create promotion, 404 handling, overlapping drains, crash recovery, pull + reconcile |
| `ConflictResolverTests` | 7 | Every branch of the LWW matrix |
| `ImageDownsamplerTests` | 4 | Pixel reduction, aspect ratio, compression, invalid input |

`SyncServiceTests` runs against an in-memory `ModelContainer`, and the mock service and
monitor let every path — including offline and server-error cases — be exercised
deterministically without touching the network.

```bash
xcodebuild test -project Gallax.xcodeproj -scheme Gallax \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:GallaxTests
```

---

## 🚀 Getting Started

| Requirement | Version |
|---|---|
| Xcode | 26.6 |
| iOS deployment target | 26.5 |
| Swift | 5.0 mode |

```bash
git clone <repo-url>
cd Gallax
open Gallax.xcodeproj
```

Select the **Gallax** scheme and run on any iOS simulator or device. There is no package
manager step.

```bash
# Build from the command line
xcodebuild -project Gallax.xcodeproj -scheme Gallax \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

---

## 🔌 API

Gallax talks to [dummyjson.com](https://dummyjson.com/products), a public mock REST API.

| Endpoint | Use |
|---|---|
| `GET /products?limit=0` | Full catalogue (194 products) |
| `POST /products/add` | Create |
| `PUT /products/{id}` | Update |
| `DELETE /products/{id}` | Delete |

> ⚠️ **Writes are simulated.** dummyjson acknowledges `POST /products/add` with a synthetic
> id (always `195`) but never stores the record, so a follow-up `PUT`/`DELETE` on that id
> returns **404**.

Gallax handles this explicitly. Items created on-device are flagged `isLocallyCreated`, and
a 404 on such an item is treated as *"this device owns the only copy"* — the change is
retired as synced rather than retried into a permanent failure. A 404 on a **server-origin**
item is still reported as a genuine failure, and a 404 on a **delete** is treated as
success, matching idempotent DELETE semantics.

---

