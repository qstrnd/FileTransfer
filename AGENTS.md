# FileTransfer — Architecture Guide for AI Agents

Read this file before writing or modifying any Swift code. The rules here are enforced via code review and should not be bent for convenience.

---

## Folder structure

```
FileTransfer/
├── App/                        # Entry point only — navigation coordinator + root view
├── Core/
│   ├── Domain/                 # Shared entities and service gate protocols
│   └── Data/                   # Concrete infrastructure shared across features
└── Features/<Name>/            # One folder per screen / bounded context
    ├── Domain/                 # Feature-scoped entities, gate protocols, pure logic
    ├── Infrastructure/         # Framework adapters and concrete gate implementations
    ├── Presentation/           # Views, ViewModels, Components/
    └── <SubFeature>/           # Sub-feature with its own Domain / Infrastructure / Presentation
```

Features that are simple enough may omit the sub-folder split (e.g. Onboarding uses Presentation/ + Infrastructure/ only). Add sub-folders when a feature grows beyond ~3 files per concern.

---

## Clean Architecture layers

### Domain

**What:** Pure Swift. No framework imports (no UIKit, no SwiftUI, no AVFoundation, no Photos, no network). Contains:
- **Entities** — plain structs or enums modelling business concepts (`Peer`, `MediaItem`, `TransferRecord`)
- **Gate protocols** — thin interfaces describing what the domain *requires* from the outside world (`NearbySessionService`, `ThumbnailGate`, `MediaSavingGate`)
- **Pure business logic** — functions or methods with no side effects and no framework dependencies (`ConnectionPolicy`, `Peer.parseDisplayName`)

**Rules:**
- `import Foundation` is allowed. Nothing else.
- No `class` unless mutation semantics are required; prefer `struct`.
- No factory methods that touch the filesystem, network, or UI. Those belong in Infrastructure.
- Gate protocols are defined here even though their concrete implementations live in Infrastructure.

**Platform primitive exception:** `UIImage`, `URL`, and `CGSize` may appear in gate protocol signatures for iOS-only modules where no cross-platform requirement exists. They are considered platform primitives, not framework dependencies. Document any such exception in a comment above the protocol.

---

### Infrastructure

**What:** Concrete adapters that satisfy domain gate protocols by interacting with Apple frameworks. Contains:
- Implementations of gate protocols (`MediaSaveService: MediaSavingGate`, `MediaThumbnailService: ThumbnailGate`)
- Bridging/adapter types that translate framework callbacks into domain events (`PeerSessionAdapter`, `MediaItemLoader`)

**Rules:**
- Every type here must either implement a domain gate protocol or be a framework adapter with no domain logic.
- Business logic (policy decisions, state transitions, data transformations) must NOT live here. Extract it to Domain.
- Infrastructure types must not import each other; they depend on Domain only.
- **`UIViewRepresentable` is not Infrastructure.** A type that renders UI belongs in Presentation regardless of whether it internally uses UIKit (`UIWindow`, `UITextField`, `UIHostingController`). The deciding question is: *does this type render UI?* If yes → Presentation. If it translates framework events into domain events (no rendering) → Infrastructure.

---

### Presentation

**What:** SwiftUI views, `@Observable` ViewModels, and UIViewControllerRepresentable bridges for picker/sheet UI. Contains:
- **ViewModel** — `@Observable final class`. Owns all mutable state for a screen. Receives gate protocols via `init`; never instantiates concrete infra types directly.
- **View** — SwiftUI `View` struct. Depends on its ViewModel (passed as a plain `var`). May depend on gate protocols to pass down to child views that need them.
- **Components/** — focused sub-views extracted from the main view. No `ViewModel` of their own unless they manage non-trivial independent state.

**Rules:**
- ViewModels hold gate protocols by their protocol type (`any ThumbnailGate`), not by the concrete implementation type.
- Views never import Infrastructure; they receive services through their ViewModel or via explicit parameters.
- Prefer passing gate instances down the call chain explicitly over `@Environment` unless the gate is truly app-wide.
- No business logic in views. A view should be able to be replaced with a mock view without breaking any logic.

---

## Gates (ports & adapters)

A **gate** is a protocol defined in Domain that abstracts one infrastructure capability. Each gate has:
1. A lean protocol in Domain (no implementation detail)
2. One or more concrete adapters in Infrastructure that `import` the relevant framework and implement the protocol
3. A ViewModel or use-case in Presentation that holds `any GateProtocol` — injected via `init`

```
Domain/ThumbnailGate.swift          protocol ThumbnailGate { … }
Infrastructure/MediaThumbnailService.swift   final class MediaThumbnailService: ThumbnailGate { … }
Presentation/SearchViewModel.swift   let thumbnailGate: any ThumbnailGate   // injected
```

**When to create a gate:**
- When Presentation or Domain needs something that requires a framework import (Photos, AVFoundation, MultipeerConnectivity, CoreData)
- When a behaviour needs to be mockable for tests
- When the same capability could plausibly have more than one implementation

**When NOT to create a gate:**
- Pure data helpers used only within a single infrastructure type
- One-line UIKit helpers with no business significance

---

## Naming conventions

| Type | Suffix | Example |
|---|---|---|
| Gate protocol | `Gate` | `ThumbnailGate`, `MediaSavingGate` |
| Gate implementation | `Service` or descriptive noun | `MediaThumbnailService`, `MediaSaveService` |
| Framework adapter (no protocol) | `Adapter` or `Loader` | `PeerSessionAdapter`, `MediaItemLoader` |
| ViewModel | `ViewModel` | `SearchViewModel` |
| UIKit bridge (UIViewControllerRepresentable) | descriptive, no suffix | `MediaPickerView`, `EmojiKeyboard` |
| UIKit overlay (window-based) | `Pinned*` | `PinnedToast`, `PinnedWindow` |
| ViewController extension file | `+<Concern>` | `TransferCurtainViewController+Layout` |

---

## State management

Use the **Observation framework** exclusively (`@Observable`, `@State`, `@Bindable`). Never use `ObservableObject`, `@Published`, `@StateObject`, or `@ObservedObject`.

| Scenario | Wrapper |
|---|---|
| View **owns** an `@Observable` object | `@State` |
| View **receives** an `@Observable` from outside | plain `var` |
| Binding into a locally-owned `@Observable` | `$state.property` |
| Binding into an externally-provided `@Observable` | `@Bindable var` |

---

## Concurrency

The project uses **Swift 6.0 strict concurrency** with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — the entire app is implicitly `@MainActor`.

- Use `async`/`await` and structured concurrency. Never reach for `DispatchQueue` or completion handlers when an async alternative exists.
- `nonisolated` is for pure, stateless, thread-safe helpers only.
- `Task { @MainActor in … }` is only for deferring past the current synchronous scope (e.g. after layout). It is not a substitute for a proper async call chain.
- Infrastructure types that implement `@MainActor` gate protocols must be `@MainActor` themselves.

---

## Xcode project

The project uses `PBXFileSystemSynchronizedRootGroup` (Xcode 16+). **All files on disk inside the project folder are automatically compiled.** Never edit `.xcodeproj` to add or remove files — just create/delete files on disk.

---

## Import discipline

| Layer | Allowed imports |
|---|---|
| Domain | `Foundation` only (+ platform primitives exception, see §Domain) |
| Infrastructure | Any Apple framework required by the adapter |
| Presentation | `SwiftUI`, `UIKit` (for UIViewControllerRepresentable), `Foundation` |
| App | `SwiftUI`, `Foundation`, `SwiftData` |

Infrastructure and Presentation types must never import each other's sibling files through the module — they communicate through Domain protocols only.

---

## Adding new code — decision tree

```
New screen?
  → Features/<Name>/Presentation/  (View + ViewModel)
  → Register in AppCoordinator

New shared entity or protocol?
  → Core/Domain/

New framework-specific implementation of a shared protocol?
  → Core/Data/

New feature-scoped entity or gate protocol?
  → Features/<Name>/Domain/

New framework adapter implementing a feature gate?
  → Features/<Name>/Infrastructure/

New sub-view extracted from a screen view?
  → Features/<Name>/Presentation/Components/

New UIKit view controller (complex gesture/layout)?
  → Features/<Name>/Presentation/  (or TransferCurtain/ sub-folder)
  → Split into +Layout / +DataSource / +Gesture extensions if > 200 lines
```

---

## Git

Commit after each self-contained, green-building change. Never commit a broken build. Commit messages state *why*, not *what* — the diff already shows what changed.
