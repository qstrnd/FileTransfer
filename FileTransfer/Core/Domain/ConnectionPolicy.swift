/// Pure, stateless business rules for peer connections.
/// All methods are static — no storage, no side effects, trivially testable.
enum ConnectionPolicy {

    // MARK: - Initiation rules

    /// Returns `true` when the local user is allowed to initiate a connection to
    /// a peer currently in `state`. This is the single source of truth for
    /// whether the "tap to connect" gesture should be honoured.
    static func canInitiate(from state: PeerConnectionState) -> Bool {
        // A valid transition exists exactly when canInitiate should be true.
        state.applying(.initiateConnection) != nil
    }

    // MARK: - Auto-reconnect (infrastructure only — behaviour deferred)

    /// Returns `true` when the two devices have successfully connected before
    /// and therefore qualify for automatic re-connection.
    ///
    /// - Important: Calling this method does **not** initiate any connection.
    ///   Auto-reconnect behaviour is intentionally **not wired up** pending a
    ///   security review (see Rule 5 in AGENTS.md). Concerns include:
    ///   - UUID spoofing: any device can claim a known UUID; MPC encryption
    ///     provides transport security but no cryptographic identity proof.
    ///   - Implicit consent: silently accepting invitations removes user agency.
    ///   - Recommended mitigations before enabling: store the peer display name
    ///     alongside the UUID, show a confirmation dialog on the first auto-
    ///     reconnect attempt, and consider a TOFU (trust-on-first-use) model.
    static func qualifiesForAutoReconnect(
        to peer: Peer,
        history: some ConnectionHistoryStore
    ) -> Bool {
        guard let id = peer.deviceID else { return false }
        return history.hasConnected(to: id)
    }
}
