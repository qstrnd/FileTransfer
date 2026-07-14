# FileTransfer — Architecture Guide for AI Agents

Read this file before writing or modifying any Swift code. The rules here are enforced via code review and should not be bent for convenience.

> **What this architecture is.** MVVM + ports & adapters, organised around Clean Architecture's dependency rule. We borrow Clean Architecture's layering and its one non-negotiable law (dependencies point inward), but we are not dogmatic about the four-ring diagram. Where this doc and a textbook disagree, this doc wins — and explains why.

---

## The one rule everything else serves

**Source dependencies point only inward.** Outer layers know about inner layers; inner layers never know about outer ones.

```
        App  ─────────────┐
                          ▼
   Presentation ────►  Use Cases ────►  Domain
                          ▲                ▲
   Infrastructure ────────┘────────────────┘
```

Concretely:

- **Domain** depends on nothing (only `Foundation` — see §Import discipline for the exact boundary).
- **Use Cases** depend on Domain only — entities and gate protocols. Never on Infrastructure or Presentation.
- **Infrastructure** depends on Domain (implements gate protocols). Never on Use Cases or Presentation.
- **Presentation** depends on Use Cases and Domain. Never on Infrastructure concrete types.
- **App** (composition root) depends on everything — the only place that wires concrete Infrastructure to the protocols Use Cases and ViewModels consume.

Two cross-cutting corollaries:

- **Features never depend on each other.** A `Features/A` type may not import or reference a `Features/B` type. Anything shared moves to `Core/`.
- **Features may depend on `Core/*`**, never the reverse. Core knows nothing about any feature.

If a proposed change satisfies the folder table but violates inward dependency, the rule wins.

---

## Folder structure

```
FileTransfer/
├── App/                        # Composition root: coordinator, root view, DI wiring
├── Core/
│   ├── Domain/                 # Shared entities, gate protocols, pure logic
│   ├── Data/                   # Concrete infrastructure shared across features
│   └── Presentation/           # SwiftUI/UIKit color tokens and other view-layer bits shared by 2+ features
└── Features/<Name>/
    ├── Domain/                 # Feature-scoped entities, gate protocols, pure logic
    ├── UseCases/               # Feature-scoped workflows orchestrating gates
    ├── Infrastructure/         # Framework adapters and concrete gate implementations
    ├── Presentation/           # Views, ViewModels, Components/
    └── <SubFeature>/           # Sub-feature with its own Domain / UseCases / Infrastructure / Presentation
```

Features simple enough may omit sub-folders. Add a folder when a concern grows beyond ~3 files. A feature with no multi-step gate orchestration may omit `UseCases/` — but the moment a ViewModel implements a dependent chain across gates (call A, use result to drive B, handle partial failure), that logic moves to a use case.

---

## Layers

### Domain

**What:** Pure Swift. Contains:
- **Entities** — plain structs/enums modelling business concepts (`Peer`, `MediaItem`, `TransferRecord`).
- **Gate protocols** — thin interfaces describing what inner layers require from the outside world (`NearbySessionService`, `ThumbnailGate`, `MediaSavingGate`).
- **Pure business logic** — side-effect-free functions/methods with no framework dependencies (`ConnectionPolicy`, `Peer.parseDisplayName`).
- **Domain errors** — the canonical failure vocabulary. Infrastructure maps framework errors into these at the boundary; nothing inward ever sees an `NSError` or framework-specific failure type.

**Rules:**
- `import Foundation` only. **No UIKit, SwiftUI, AVFoundation, Photos, or any other Apple framework.**
- `UIImage` is not allowed in Domain — it requires `import UIKit` and is a rendering concern, not a business concept. Gate protocols that deal with image data return `Data`; Presentation converts `Data → UIImage` at the boundary.
- No `class` unless mutation semantics are required; prefer `struct`.
- Domain value types and pure functions are `nonisolated` by default. The whole-module `MainActor` isolation is a Presentation/App convenience — Domain opts out so business logic can run anywhere and be tested off the main actor. If you write a domain `class`, mark it `nonisolated` explicitly.
- No factory methods that touch the filesystem, network, or UI. Those belong in Infrastructure.

---

### Use Cases

**What:** Stateful, effectful orchestration spanning one or more gates to fulfil an intent.

- Named for the intent: `SendMediaUseCase`, `ConnectToPeerUseCase`.
- Holds the gate protocols it needs, injected via `init` as `any GateProtocol`.
- Exposes intent-level methods (`func send(_ items: [MediaItem], to peers: [Peer])`), not gate-level CRUD.
- May be `@Observable` so a ViewModel can forward its state to the view.
- Returns Domain types and throws Domain errors. Never leaks a framework type.

**Rules:**
- Use Cases depend on Domain only. They never `import` a framework and never reference a concrete Infrastructure type.
- A workflow used by two screens lives in `Core/UseCases/` exactly once.
- Pure decisions within a workflow delegate to Domain logic (`ConnectionPolicy`), keeping the use case focused on orchestration and side effects.
- **The threshold for extraction:** a ViewModel that holds two independent gates and routes different user actions to each is fine. Extract to a use case when the ViewModel executes a *dependent chain* — the result of one gate call drives a subsequent call — or when the same multi-step flow would otherwise be duplicated across ViewModels.

---

### Infrastructure

**What:** Concrete adapters satisfying domain gate protocols by interacting with Apple frameworks.
- Gate implementations (`MediaSaveService: MediaSavingGate`, `MediaThumbnailService: ThumbnailGate`).
- Bridging adapters translating framework callbacks into domain events (`PeerSessionAdapter`, `MediaItemLoader`).
- Framework-error → Domain-error mapping happens here.

**Rules:**
- Every type either implements a domain gate protocol or is a framework adapter with no domain logic.
- Business logic (policy, state transitions, data transformations) must NOT live here — extract to Domain (pure) or Use Cases (orchestration).
- Infrastructure types collaborate only through Domain gate protocols, never through concrete sibling types.
- **`UIViewRepresentable` is not Infrastructure.** A type that renders UI belongs in Presentation regardless of whether it internally uses UIKit (`UIWindow`, `UITextField`, `UIHostingController`). Deciding question: *does this type render UI?* Yes → Presentation. Translates framework events into domain events, no rendering → Infrastructure.

---

### Presentation

**What:** SwiftUI views, `@Observable` ViewModels, and UIViewControllerRepresentable bridges.

- **ViewModel** — `@Observable final class`. Owns mutable view state for a screen and maps between use cases and the view. Receives use cases (and, for trivial single-gate screens, a gate directly) via `init`. Never instantiates concrete Infrastructure types.
- **View** — SwiftUI `View` struct. Depends on its ViewModel via plain `var`. May pass gates or use cases down to child views explicitly.
- **Components/** — focused sub-views. No ViewModel of their own unless they manage non-trivial independent state.

**Rules:**
- ViewModels hold use cases by type and gates as `any GateProtocol`. Never hold a concrete Infrastructure type.
- Views never import Infrastructure; they receive services through their ViewModel or explicit parameters.
- Prefer explicit parameter passing over `@Environment`. The only sanctioned use of `@Environment` is for genuinely app-scoped state that spans multiple screens (e.g. a live session store owned at the composition root).
- No business logic in views. A view must be replaceable with a mock view without breaking any logic.

---

## Colors & dark mode

Every screen must look correct in both light and dark mode. This is enforced the same way as any other architectural rule, not left to visual QA.

**Rules:**
- **No hardcoded literal colors for anything that sits on a themed background** — no `.white`, `.black`, or raw `UIColor(red:green:blue:)` / `Color(red:green:blue:)` for a fill, background, or border that appears over `.systemBackground`/`.systemGroupedBackground`/a custom surface. Use a semantic system color (`.secondarySystemGroupedBackground`, `.systemFill`, `.quaternarySystemFill`, `.separator`, etc.) or a named constant with explicit light/dark branches. A literal `.white` card is invisible on a white light-mode background it happens to match, and looks jarring/flat on a near-black dark-mode background — both are bugs, not style choices.
- **Every custom (non-system) color constant must define both variants**, e.g.:
  ```swift
  static var myBadgeBG: UIColor {
      UIColor { traits in
          traits.userInterfaceStyle == .dark ? darkValue : lightValue
      }
  }
  ```
  For SwiftUI, prefer `Color(.someUIColorSemanticName)` or the same `UIColor { traits in }` pattern wrapped in `Color(uiColor:)`. Dark values are not the light value darkened uniformly — follow the same light↔dark relationship Apple's own system colors use (pale/light-mode washes become deep, muted, still-hued dark washes, not gray).
- **Colors live in named constants, never inline literals at the call site.** One `extension UIColor` / `extension Color` per concern, colocated with the feature that owns it (e.g. `TransferTypeColors.swift`, `TransferCurtainColors.swift`). A color used by 2+ features moves to `Core/Presentation/` (e.g. `AppColors.swift`) — features never reference another feature's color file, same as any other cross-feature reference.
- **`CALayer` properties that store `CGColor` (`borderColor`, gradient `colors`, `shadowColor`) do not auto-update on trait changes** the way `UIView.backgroundColor`/SwiftUI `Color` do. Any view setting these must: (1) register via `registerForTraitChanges` and re-resolve using `self.traitCollection` — **not** the handler's second parameter, which is the *previous* trait collection, matching the old `traitCollectionDidChange(_ previousTraitCollection:)` — and (2) refresh again on `UIApplication.willEnterForegroundNotification`, since a CGColor snapshot goes stale if the system appearance changed while the app was backgrounded.
- Verify visually in the simulator in both appearances (`xcrun simctl ui <device> appearance dark|light`) before considering a color change done — don't rely on reading the code.

---

## Gates (ports & adapters)

A **gate** is a protocol that abstracts one infrastructure capability. Anatomy:

```
Features/Search/Media/Domain/ThumbnailGate.swift
    protocol ThumbnailGate { func thumbnail(for url: URL, isVideo: Bool) async -> Data? }

Features/Search/Media/Infrastructure/MediaThumbnailService.swift
    final class MediaThumbnailService: ThumbnailGate { … }   // imports AVFoundation, UIKit

Features/Search/UseCases/SomeUseCase.swift
    let thumbnailGate: any ThumbnailGate   // injected via init
```

**Gate ownership.** A gate lives in the Domain folder of the layer that consumes it. Feature-specific gates belong in `Features/<Name>/Domain/`, **not** `Core/Domain/`. Promote to `Core/Domain/` only when two or more features genuinely consume the same gate.

**When to create a gate:**
- A use case or ViewModel needs something requiring a framework import (Photos, AVFoundation, MultipeerConnectivity, SwiftData).
- A behaviour must be mockable for tests.
- The same capability could plausibly have more than one implementation.

**When NOT to create a gate:**
- Pure data helpers used only within a single Infrastructure type.
- One-line UIKit helpers with no business significance.

---

## Persistence & SwiftData

SwiftData `@Model` types are framework-coupled reference types and **cannot live in Domain.**

- **Domain entity** (`TransferRecord`, a plain struct) is the type that flows through Use Cases and Presentation.
- **Persistence model** (`TransferItem`, the `@Model`) lives in `Core/Data/` and is an implementation detail of a persistence gate.
- A **persistence gate** (`TransferHistoryGate`) is defined in Domain; its Infrastructure implementation maps Domain ⇄ `@Model` at the boundary.

Nothing inward of Infrastructure ever references a `@Model`. `App` may `import SwiftData` solely to set up the `ModelContainer` at the composition root.

---

## Naming conventions

| Type | Suffix | Example |
|---|---|---|
| Gate protocol | `Gate` | `ThumbnailGate`, `MediaSavingGate`, `TransferHistoryGate` |
| Gate implementation | `Service` or descriptive noun | `MediaThumbnailService`, `MediaSaveService` |
| Use case / interactor | `UseCase` | `SendMediaUseCase`, `ConnectToPeerUseCase` |
| Framework adapter (no protocol) | `Adapter` or `Loader` | `PeerSessionAdapter`, `MediaItemLoader` |
| ViewModel | `ViewModel` | `SearchViewModel` |
| Domain error | `Error` | `TransferError`, `ConnectionError` |
| SwiftData model | `Item` (current) / `Model` (new) | `TransferItem` |
| UIKit bridge (`UIViewControllerRepresentable`) | descriptive, no suffix | `MediaPickerView`, `EmojiKeyboard` |
| UIKit overlay (window-based) | `Pinned*` | `PinnedToast`, `PinnedWindow` |
| ViewController extension file | `+<Concern>` | `TransferCurtainViewController+Layout` |

---

## State management

Use the **Observation framework** exclusively. Never use `ObservableObject`, `@Published`, `@StateObject`, or `@ObservedObject`.

| Scenario | Wrapper |
|---|---|
| View **owns** an `@Observable` object | `@State` |
| View **receives** an `@Observable` from outside | plain `var` |
| Binding into a locally-owned `@Observable` | `$state.property` |
| Binding into an externally-provided `@Observable` | `@Bindable var` |
| App-scoped cross-screen state (live session store) | owned at `App/`, injected down; `@Environment` permitted |

---

## Concurrency

Swift 6.0 strict concurrency. `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — the app is implicitly `@MainActor`.

- **Domain opts out.** Domain class types and domain global functions must be `nonisolated`. Value types are already `nonisolated` regardless of the module default.
- Use `async`/`await` and structured concurrency. Never reach for `DispatchQueue` or completion handlers when an async alternative exists.
- `Task { @MainActor in … }` is only for deferring past the current synchronous scope (e.g. `becomeFirstResponder` after layout). It is not a substitute for a proper async call chain.
- Infrastructure types implementing `@MainActor` gate protocols must be `@MainActor` themselves.

---

## Xcode project

Uses `PBXFileSystemSynchronizedRootGroup` (Xcode 16+). **All files on disk inside the project folder are automatically compiled.** Never edit `.xcodeproj` to add or remove files — just create/delete files on disk.

---

## Import discipline

| Layer | Allowed imports |
|---|---|
| Domain | `Foundation` only — no `UIKit`, no `UIImage`, no framework types |
| Use Cases | `Foundation` only — composes Domain gates, imports no framework |
| Infrastructure | Any Apple framework required by the adapter |
| Presentation | `SwiftUI`, `UIKit` (for UIViewControllerRepresentable / UIKit bridges), `Foundation` |
| App | `SwiftUI`, `Foundation`, `SwiftData` |

Infrastructure and Presentation communicate through Domain protocols only — never through concrete sibling imports. Feature → feature imports are forbidden at every layer.

---

## Adding new code — decision tree

```
New screen?
  → Features/<Name>/Presentation/  (View + ViewModel)
  → Register in AppCoordinator

Dependent gate chain or multi-step flow?
  → Features/<Name>/UseCases/   (or Core/UseCases/ if shared across features)
  → ViewModel calls it; ViewModel does NOT implement the orchestration itself

New shared entity, gate protocol, or domain error (used by 2+ features)?
  → Core/Domain/

New color constant used by only one feature?
  → Features/<Name>/Presentation/<Name>Colors.swift

New color constant used by 2+ features?
  → Core/Presentation/AppColors.swift

New framework-specific implementation of a shared Core protocol?
  → Core/Data/

New feature-scoped entity, gate protocol, or pure logic?
  → Features/<Name>/Domain/

New framework adapter implementing a feature gate?
  → Features/<Name>/Infrastructure/

New persistence @Model?
  → Core/Data/ (or feature Infrastructure)
  → Expose via a Domain persistence gate; map Domain ⇄ Model at the boundary

New sub-view?
  → Features/<Name>/Presentation/Components/

New UIKit view controller (complex gesture/layout)?
  → Features/<Name>/Presentation/
  → Split into +Layout / +DataSource / +Gesture extensions if > 200 lines
```

---

## Suspended features

Some capabilities are gated off in `Core/Domain/TransferFeatureFlags.swift` and are **not currently supported**. Do not extend, "fix", or build new work on top of them, and do not re-enable a flag as a side effect of unrelated work.

- **Contact sharing** (`contactSharing`, off) — sending contacts is suspended. The "Contact" share action is hidden while the flag is off. Treat the contact send/receive path as frozen: no new features, and prefer not to reference it from new code.

When a flag is off, keep its code paths intact (so it can be revived) but inert. New entry points for a suspended feature must stay behind its flag.

---

## Git

Commit after each self-contained, green-building change. Never commit a broken build. Commit messages state *why*, not *what*.
