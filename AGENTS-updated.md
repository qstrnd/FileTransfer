# FileTransfer — Architecture Guide for AI Agents

Read this file before writing or modifying any Swift code. The rules here are enforced via code review and should not be bent for convenience.

> **What this architecture is.** This is **MVVM + ports & adapters**, organised around Clean Architecture's dependency rule. We borrow Clean Architecture's layering and its one non-negotiable law (dependencies point inward), but we are not dogmatic about the four-ring diagram. Where this doc and a Clean Architecture textbook disagree, this doc wins — but it will tell you *why* it diverges.

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

- **Domain** depends on nothing (only `Foundation`, and only `nonisolated` value types/pure functions).
- **Use Cases** depend on Domain (entities + gate protocols). Never on Infrastructure or Presentation.
- **Infrastructure** depends on Domain (it *implements* gate protocols). Never on Use Cases or Presentation.
- **Presentation** depends on Use Cases and Domain. Never on Infrastructure concrete types.
- **App** (composition root) depends on everything — it is the only place that wires concrete Infrastructure to the protocols Use Cases and ViewModels consume.

Two cross-cutting corollaries that prevent ball-of-mud rot:

- **Features never depend on each other.** A `Features/A` type may not import or reference a `Features/B` type. Anything shared between features moves to `Core/`.
- **Features may depend on `Core/*`**, never the reverse. Core knows nothing about any feature.

Everything below is a consequence of this rule. If a proposed change satisfies the folder table but violates inward dependency, the rule wins.

---

## Folder structure

```
FileTransfer/
├── App/                        # Composition root: navigation coordinator, root view, DI wiring
├── Core/
│   ├── Domain/                 # Shared entities, gate protocols, pure logic
│   ├── UseCases/               # Shared cross-feature workflows
│   └── Data/                   # Concrete infrastructure shared across features
└── Features/<Name>/
    ├── Domain/                 # Feature-scoped entities, gate protocols, pure logic
    ├── UseCases/               # Feature-scoped workflows orchestrating gates
    ├── Infrastructure/         # Framework adapters and concrete gate implementations
    ├── Presentation/           # Views, ViewModels, Components/
    └── <SubFeature>/           # Sub-feature with its own Domain / UseCases / Infrastructure / Presentation
```

Features simple enough may omit sub-folders (e.g. Onboarding uses Presentation/ + Infrastructure/ only). Add a folder when a feature grows beyond ~3 files per concern. A feature with no multi-step orchestration may omit `UseCases/` — but the moment a ViewModel starts coordinating two or more gates, that logic moves to a use case (see §Use Cases).

---

## Clean Architecture layers

### Domain

**What:** Pure Swift. Contains:
- **Entities** — plain structs/enums modelling business concepts (`Peer`, `MediaItem`, `TransferRecord`).
- **Gate protocols** — thin interfaces describing what inner layers *require* from the outside world (`NearbySessionService`, `ThumbnailGate`, `MediaSavingGate`).
- **Pure business logic** — side-effect-free functions/methods with no framework dependencies (`ConnectionPolicy`, `Peer.parseDisplayName`).
- **Domain errors** — the canonical failure vocabulary (`TransferError`, `ConnectionError`). Infrastructure maps framework errors into these at the boundary; nothing inward of Infrastructure ever sees an `NSError` or a framework-specific failure.

**Rules:**
- `import Foundation` is allowed. **Nothing else** — see the platform-primitive note below for the precise boundary.
- Domain types are **`nonisolated` by default.** Whole-module `MainActor` isolation (see §Concurrency) is an app convenience; Domain opts out so pure logic can run anywhere and be tested off the main actor. Mark value types and pure functions `nonisolated` explicitly where the module default would otherwise isolate them.
- No `class` unless mutation semantics are required; prefer `struct`.
- No factory methods that touch filesystem, network, or UI. Those belong in Infrastructure.
- Gate protocols are defined here even though concrete implementations live in Infrastructure.

**Platform-primitive boundary (read carefully — this replaces the old "exception").**
- `URL` is Foundation. Always allowed.
- `CGSize`, `CGRect`, `CGFloat` reach Domain through Foundation on Apple platforms and are allowed in signatures as value primitives.
- **`UIImage` is NOT allowed in Domain.** It requires `import UIKit`, which the import rule forbids, and a bitmap-for-display is a *rendering* concern, not a business concept. A gate must not traffic in `UIImage`. Instead, return a domain-neutral type — raw `Data`, or a thin `Thumbnail { data: Data; size: CGSize }` — and let a Presentation/Infrastructure adapter convert to `UIImage` at the edge. This keeps Domain free of UIKit and keeps gates unit-testable without a UIKit-linked test host.

---

### Use Cases (application layer)

**What:** Stateful, effectful orchestration that spans one or more gates to fulfil an intent. This layer is the home for everything that is "business workflow" but not "pure rule." A file-transfer app *is* its workflows, so this layer carries real weight.

- **Interactors** — `final class` (or `actor` where appropriate) named for the intent: `TransferFileUseCase`, `ConnectToPeerUseCase`, `SaveReceivedMediaUseCase`.
- Each holds the gate protocols it needs (injected via `init`, as `any GateProtocol`).
- Exposes intent-level methods (`func transfer(_ item: MediaItem, to peer: Peer) async throws`), not gate-level CRUD.
- Returns Domain types and throws Domain errors. Never leaks a framework type or an Infrastructure concrete type to its caller.

**Rules:**
- Use Cases depend on Domain only. They never import a framework and never reference an Infrastructure concrete type — they compose *gates*.
- A workflow used by two screens lives here exactly once; ViewModels call it rather than re-implementing it.
- Pure decisions inside a workflow (e.g. "should we auto-accept this peer?") delegate to Domain pure logic (`ConnectionPolicy`), keeping the use case focused on orchestration and side effects.

**Why this layer exists:** without it, multi-gate orchestration falls into ViewModels (making them fat coordinators that can't be reused) or into Domain (which then can't stay pure). Use Cases absorb that pressure so Domain stays pure and Presentation stays thin.

---

### Infrastructure

**What:** Concrete adapters satisfying domain gate protocols by talking to Apple frameworks.
- Gate implementations (`MediaSaveService: MediaSavingGate`, `MediaThumbnailService: ThumbnailGate`).
- Bridging/adapter types translating framework callbacks into domain events (`PeerSessionAdapter`, `MediaItemLoader`).
- Framework-error → Domain-error mapping happens here.

**Rules:**
- Every type either implements a domain gate protocol or is a framework adapter with no domain logic.
- Business logic (policy, state transitions, data transformations) must NOT live here — extract to Domain (pure) or Use Cases (orchestration).
- **Infrastructure types collaborate only through Domain gate protocols, never through concrete sibling types.** Shared plumbing (e.g. a `FileSystemClient`) is itself expressed as a Domain gate and injected, so two adapters can compose without an outer-to-outer concrete dependency. (This relaxes the old "must not import each other" rule, which forced either duplication or leaking coordination up into ViewModels.)
- **`UIViewRepresentable` is not Infrastructure.** A type that *renders UI* belongs in Presentation regardless of whether it internally uses UIKit (`UIWindow`, `UITextField`, `UIHostingController`). Deciding question: *does this type render UI?* Yes → Presentation. Translates framework events into domain events with no rendering → Infrastructure.

---

### Presentation

**What:** SwiftUI views, `@Observable` ViewModels, and UIViewControllerRepresentable bridges for picker/sheet UI.

- **ViewModel** — `@Observable final class`. Owns mutable **view** state for a screen and maps between use cases and the view. Receives **use cases** (and, only for trivial single-gate screens, a gate) via `init`; never instantiates concrete infra types directly.
- **View** — SwiftUI `View` struct depending on its ViewModel (plain `var`).
- **Components/** — focused sub-views. No `ViewModel` of their own unless they manage non-trivial independent state.

**Rules:**
- ViewModels hold **use cases** by type (`TransferFileUseCase`), and gates only as `any GateProtocol` for the trivial single-gate case. They never hold a concrete Infrastructure type.
- ViewModels orchestrate *view state*, not *business workflow*. The moment a ViewModel coordinates two or more gates or implements a multi-step effectful flow, that logic belongs in a Use Case.
- Views never import Infrastructure; they receive services through their ViewModel or explicit parameters.
- Prefer passing dependencies down the call chain explicitly over `@Environment`. **Trade-off acknowledged:** explicit drilling means wiring *is* a Presentation responsibility, which slightly dilutes "views hold no logic." We accept this for testability and traceability. The single sanctioned `@Environment` use is app-scoped state (see §State management).
- No business logic in views. A view should be replaceable with a mock view without breaking any logic.

---

## Gates (ports & adapters)

A **gate** is a protocol that abstracts one infrastructure capability. Each gate has:
1. A lean protocol **owned by the layer that needs it** (see ownership below).
2. One or more concrete adapters in Infrastructure that `import` the framework and implement it.
3. A Use Case (or, for trivial screens, a ViewModel) that holds `any GateProtocol`, injected via `init`.

```
Features/Search/Domain/ThumbnailGate.swift           protocol ThumbnailGate { … }
Features/Search/Infrastructure/MediaThumbnailService.swift  final class MediaThumbnailService: ThumbnailGate { … }
Features/Search/UseCases/LoadThumbnailsUseCase.swift  let thumbnailGate: any ThumbnailGate   // injected
```

**Gate ownership.** A gate lives in the Domain of the layer that consumes it. A gate used only by Search belongs in `Features/Search/Domain/`, **not** `Core/Domain/`. Promote a gate to `Core/Domain/` only when two or more features genuinely consume it. Ports are owned by who needs them, not dumped into a shared kernel.

**When to create a gate:**
- Presentation, a Use Case, or Domain needs something requiring a framework import (Photos, AVFoundation, MultipeerConnectivity, SwiftData).
- A behaviour must be mockable for tests.
- The same capability could plausibly have more than one implementation.

**When NOT to create a gate:**
- Pure data helpers used only within a single infrastructure type.
- One-line UIKit helpers with no business significance.

---

## Persistence & SwiftData boundary

SwiftData `@Model` types are framework-coupled reference types and **cannot live in Domain.**

- **Domain entity** (`TransferRecord`, a pure struct) is the type that flows through Use Cases and Presentation.
- **Persistence model** (`TransferRecordModel`, the `@Model`) lives in `Core/Data/` (or the feature's Infrastructure) and is an implementation detail of a persistence gate.
- A **persistence gate** (`TransferHistoryGate`) is defined in Domain; its Infrastructure implementation maps Domain ⇄ `@Model` at the boundary.

Nothing inward of Infrastructure ever references a `@Model`. `App` may `import SwiftData` solely to stand up the `ModelContainer` at the composition root.

---

## Naming conventions

| Type | Suffix | Example |
|---|---|---|
| Gate protocol | `Gate` | `ThumbnailGate`, `MediaSavingGate` |
| Gate implementation | `Service` or descriptive noun | `MediaThumbnailService`, `MediaSaveService` |
| Use case / interactor | `UseCase` | `TransferFileUseCase`, `ConnectToPeerUseCase` |
| Framework adapter (no protocol) | `Adapter` or `Loader` | `PeerSessionAdapter`, `MediaItemLoader` |
| ViewModel | `ViewModel` | `SearchViewModel` |
| Domain error | `Error` | `TransferError`, `ConnectionError` |
| SwiftData model | `Model` | `TransferRecordModel` |
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
| **App-scoped, cross-screen state** (e.g. live Multipeer session spanning discovery → connect → transfer) | owned at the composition root (`App/`), injected downward; `@Environment` permitted here |

App-scoped state — the long-lived session store being the canonical example — is created once at the composition root, never inside whichever screen happens to touch it first. It is the **only** sanctioned use of `@Environment`; everything else is injected explicitly.

---

## Concurrency

The project uses **Swift 6.0 strict concurrency** with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — the app is implicitly `@MainActor`.

- **Domain opts out.** Pure value types and pure functions are `nonisolated` by default so business rules aren't coupled to the UI thread and can be tested off-actor. The whole-module default is a Presentation/App convenience, not a Domain constraint.
- Use `async`/`await` and structured concurrency. Never reach for `DispatchQueue` or completion handlers when an async alternative exists.
- `nonisolated` is for pure, stateless, thread-safe helpers — and for all Domain value types/pure logic, per above.
- `Task { @MainActor in … }` is only for deferring past the current synchronous scope (e.g. after layout). It is not a substitute for a proper async call chain.
- Infrastructure types implementing `@MainActor` gate protocols must be `@MainActor` themselves. A gate that does genuine background work (file I/O, network) should be declared with the isolation it actually needs, not blanket-MainActor.

---

## Xcode project

The project uses `PBXFileSystemSynchronizedRootGroup` (Xcode 16+). **All files on disk inside the project folder are automatically compiled.** Never edit `.xcodeproj` to add or remove files — just create/delete files on disk.

---

## Import discipline

| Layer | Allowed imports |
|---|---|
| Domain | `Foundation` only (+ `CGSize`/`CGRect`/`CGFloat`/`URL` value primitives; **no `UIImage`**) |
| Use Cases | `Foundation` only — composes Domain gates, imports no framework |
| Infrastructure | Any Apple framework required by the adapter |
| Presentation | `SwiftUI`, `UIKit` (for UIViewControllerRepresentable), `Foundation` |
| App | `SwiftUI`, `Foundation`, `SwiftData` |

- Infrastructure and Presentation never import each other's sibling files — they communicate through Domain protocols.
- Use Cases never import a framework. If a use case "needs" a framework, it actually needs a gate.
- **Feature → feature imports are forbidden** at every layer. Shared needs go through `Core/`.

---

## Adding new code — decision tree

```
New screen?
  → Features/<Name>/Presentation/  (View + ViewModel)
  → Register in AppCoordinator

New multi-step workflow spanning one or more gates? (the common case for transfer flows)
  → Features/<Name>/UseCases/   (or Core/UseCases/ if shared across features)
  → ViewModel calls it; ViewModel does NOT implement the orchestration itself

New shared entity, gate protocol, or domain error?
  → Core/Domain/   (only if used by 2+ features — otherwise feature Domain)

New framework-specific implementation of a shared protocol?
  → Core/Data/

New feature-scoped entity, gate protocol, or pure logic?
  → Features/<Name>/Domain/

New framework adapter implementing a feature gate?
  → Features/<Name>/Infrastructure/

New persistence model (@Model)?
  → Core/Data/ (or feature Infrastructure); expose via a Domain persistence gate; map Domain ⇄ Model at the boundary

New sub-view extracted from a screen view?
  → Features/<Name>/Presentation/Components/

New UIKit view controller (complex gesture/layout)?
  → Features/<Name>/Presentation/  (or TransferCurtain/ sub-folder)
  → Split into +Layout / +DataSource / +Gesture extensions if > 200 lines

Something shared between two features?
  → It does NOT go feature→feature. Promote it to Core/.
```

---

## Git

Commit after each self-contained, green-building change. Never commit a broken build. Commit messages state *why*, not *what* — the diff already shows what changed.
