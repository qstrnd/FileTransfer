# FileTransfer — Architecture Guide

## Structure

```
FileTransfer/
├── App/                          # Entry point & navigation
│   ├── AppCoordinator.swift      # Owns service; drives screen transitions
│   └── RootView.swift            # Switches screens based on coordinator state
│
├── Core/                         # Shared infrastructure — no UI, no feature logic
│   ├── Domain/                   # Entities, service protocols, domain types
│   │   ├── Peer.swift
│   │   ├── TransferMessage.swift
│   │   ├── NearbySessionService.swift  # Protocol + delegate
│   │   ├── NameGenerator.swift
│   │   └── DeviceInfo.swift
│   └── Data/                     # Concrete implementations of domain protocols
│       └── MultipeerNearbyService.swift
│
└── Features/                     # One folder per screen / bounded context
    ├── Onboarding/               # MVVM — files go directly here, no subfolders
    │   ├── OnboardingView.swift
    │   └── OnboardingViewModel.swift
    ├── Search/                   # Views may be split into focused sub-views
    │   ├── SearchView.swift
    │   ├── SearchViewModel.swift
    │   ├── PeerCell.swift        # Sub-view
    │   ├── PeerConnectionState.swift  # Feature-scoped type
    │   ├── SearchingText.swift   # Sub-view
    │   └── PulsingRings.swift    # Sub-view
    └── …
```

### Feature module conventions

Each feature folder is a self-contained **MVVM module**:

- **ViewModel** — `@Observable` class; owns business logic and state. Receives dependencies via `init` (closures or protocols). Never imports another feature.
- **View** — SwiftUI `View`. Talks only to its ViewModel. May be split into focused sub-views inside the same folder (e.g. `PeerCell`, `SearchingText`).
- **Sub-ViewModels** — add when a sub-view has non-trivial state; keep them scoped to the same folder.
- **Feature-scoped types** — enums, value types, extensions used only within the feature live in the same folder (e.g. `PeerConnectionState`).

No `Presentation/`, `Domain/`, or `Data/` subfolders inside a feature. The feature folder *is* the module boundary.

## Clean architecture layers

| Layer | Location | What lives here |
|---|---|---|
| **Domain** | `Core/Domain/` | Entities (`Peer`, `TransferMessage`), service protocols, pure business logic |
| **Infrastructure** | `Core/Data/` | Concrete implementations of domain protocols (MCSession adapter, etc.) |
| **Feature** | `Features/<Name>/` | Screen-specific ViewModels, Views, sub-views, and feature-scoped types |
| **App** | `App/` | Navigation coordinator, root view |

If the app grows to need explicit **repositories** or **use cases**, add them in `Core/Domain/` (protocol) and `Core/Data/` (implementation). Features call service protocols — they never reach into `Core/Data/` directly.

## State management

All ViewModels and `AppCoordinator` use the **Observation framework** (`@Observable`, iOS 17+). Never use `ObservableObject` / `@Published`.

| Scenario | Property wrapper |
|---|---|
| View **owns** the object (coordinator, onboarding VM) | `@State` |
| View **receives** the object from outside | plain `var` (no wrapper) |
| Binding to an `@Observable` property from `@State` | `$state.property` |
| Binding to an externally-received `@Observable` | `@Bindable var` |

## Language

Use **Swift 6.0** strict concurrency throughout. All types are `@MainActor` by default (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`).

- **Always prefer modern concurrency** — `async`/`await`, `AsyncStream`, `Actor`, `Task`, structured concurrency. Never use `DispatchQueue`, `OperationQueue`, or completion-handler APIs when an async alternative exists.
- Cross-actor calls must use `await`.
- UIKit delegate protocols are `@MainActor` in iOS 26; implement them as plain methods on an `@MainActor` class — no `nonisolated` needed.
- `nonisolated` is reserved for pure, stateless functions (e.g. `isValidEmoji`) callable from any isolation context.
- Use `Task { @MainActor in … }` only to defer past the current synchronous scope (e.g. `becomeFirstResponder` after a layout pass). Do not use it as a substitute for proper `async`/`await` call chains.

## Git

Commit at the end of each meaningful, self-contained chunk of work. Do not commit partial or broken states. Each commit message should say *why*, not just *what*.

## Rules

### Adding a new screen
1. Create `Features/<ScreenName>/` and add a `View` + `ViewModel` file.
2. The ViewModel receives dependencies via `init` (closures or protocols). It never imports other features.
3. Register the transition in `AppCoordinator`; wire it in `RootView`.
4. Split into sub-views as needed — keep all files in the same feature folder.

### Adding a shared capability
- **Entity or protocol** → `Core/Domain/`
- **Concrete implementation** → `Core/Data/`
- Features depend on the protocol, never on the implementation.

### Navigation
`AppCoordinator` is the single source of truth for which screen is active. It holds an optional ViewModel (e.g. `searchViewModel: SearchViewModel?`). `RootView` switches on that optional. Features signal completion via `onDismiss`/`onStop` closures — they never push navigation themselves.

### Service lifetime
`AppCoordinator` owns the `NearbySessionService` for the entire app session, passing it to feature ViewModels on construction. When a feature stops, it calls `service.stop()` and clears the service's delegate to avoid retain cycles.
