# FileTransfer — Architecture Guide

## Structure

This project is organised by **app layer** (horizontal) and **feature/screen** (vertical). Every screen is a self-contained module under `Features/`.

```
FileTransfer/
├── App/                            # Entry point & navigation
│   ├── AppCoordinator.swift        # Owns shared service; drives screen transitions
│   └── RootView.swift              # Observes coordinator; renders Setup or Transfer
│
├── Core/                           # Shared infrastructure, no UI
│   ├── Domain/
│   │   ├── Peer.swift              # Entity
│   │   ├── TransferMessage.swift   # Entity
│   │   └── NearbySessionService.swift  # Protocol + delegate protocol
│   └── Data/
│       └── MultipeerNearbyService.swift  # MCSession implementation
│
└── Features/
    ├── Setup/
    │   └── Presentation/
    │       ├── SetupViewModel.swift  # Owns name/emoji state; calls onStart closure
    │       └── SetupView.swift       # Init takes onStart: (String) -> Void
    └── Transfer/
        └── Presentation/
            ├── TransferViewModel.swift  # NearbySessionServiceDelegate; calls onStop
            └── TransferView.swift
```

## State management

All ViewModels and `AppCoordinator` use the **Observation framework** (`@Observable` macro, iOS 17+). Do not use `ObservableObject` / `@Published`.

| Scenario | Property wrapper |
|---|---|
| View **owns** the object (coordinator, setup VM) | `@State` |
| View **receives** the object from outside | plain `var` (no wrapper) |
| Need a `Binding` to an `@Observable` property from `@State` | `$state.property` |
| Need a `Binding` to an externally-received `@Observable` | `@Bindable var` |

## Language

Use **Swift 6.0** strict concurrency. All types are `@MainActor` by default (enforced via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` in build settings). Cross-actor calls must use `await`; `nonisolated` is reserved for genuinely non-isolated work (e.g. MC delegate callbacks that hop back with `Task { @MainActor in … }`).

## Git

Commit at the end of each meaningful, self-contained chunk of work — a new feature module, a refactor, a migration. Do not commit partial or broken states. Each commit message should say *why*, not just *what*.

## Rules

### Adding a new screen
1. Create `Features/<ScreenName>/Presentation/` with a `ViewModel` and a `View`.
2. The ViewModel receives any shared service or state via `init` parameters (closures or protocols). It does **not** import other feature modules.
3. Register the screen transition in `AppCoordinator` and wire it in `RootView`.

### Shared domain objects
Entities and service protocols live in `Core/Domain/`. Concrete implementations (network, persistence) live in `Core/Data/`. Features import nothing from each other — only from `Core`.

### Navigation
`AppCoordinator` is the single source of truth for which screen is active. It publishes an optional ViewModel (e.g. `transferViewModel: TransferViewModel?`). `RootView` switches on that optional. A feature signals "I'm done" by calling the `onStop`/`onDismiss` closure it received at init — it never pushes navigation itself.

### Service lifetime
`AppCoordinator` owns the `NearbySessionService` instance for the entire app session. It passes the service to feature ViewModels on construction. When a feature stops, the coordinator calls `service.stop()` (or the ViewModel does via its `stop()` method which also fires `onStop`).
