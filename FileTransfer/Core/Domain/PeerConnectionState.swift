// MARK: - State

/// All possible connection states for a remote peer from the local user's perspective.
enum PeerConnectionState: Equatable {
    case idle        // Visible, no active or pending connection
    case connecting  // Local user initiated; waiting for the remote peer to respond
    case connected   // Connection established by both sides
    case rejected    // Remote peer declined our invitation; plays shake + lock animation
}

// MARK: - Events

/// External events that drive the connection state machine.
enum ConnectionEvent: Equatable {
    case initiateConnection   // Local user taps to connect
    case connectionAccepted   // Remote peer accepted our invitation
    case connectionDeclined   // Remote peer declined our invitation
    case initiateDisconnection // Local user taps the minus badge on a connected peer
    case peerDisconnected     // Remote peer closed the connection
}

// MARK: - Transitions

extension PeerConnectionState {
    /// Returns the next state after applying `event`, or `nil` when the transition is invalid.
    ///
    /// Business rules encoded here:
    /// - Rule 1: Tapping a peer in `.idle` sends an invitation (→ `.connecting`).
    /// - Rule 2: Same tap is valid from `.rejected` — declining does not permanently block reconnection.
    /// - Rule 3: Tapping the minus badge on a `.connected` peer disconnects (→ `.idle`).
    ///           The peer that receives the disconnect event also transitions `.connected` → `.idle`.
    /// - Rule 4: After mutual disconnection both sides are `.idle` and may reconnect freely.
    func applying(_ event: ConnectionEvent) -> PeerConnectionState? {
        switch (self, event) {
        case (.idle,       .initiateConnection):    return .connecting
        case (.rejected,   .initiateConnection):    return .connecting  // Rule 2
        case (.connecting, .connectionAccepted):    return .connected
        case (.connecting, .connectionDeclined):    return .rejected
        case (.connected,  .initiateDisconnection): return .idle        // Rule 3 (initiator)
        case (.connected,  .peerDisconnected):      return .idle        // Rule 3 (receiver)
        default:                                     return nil          // Invalid transition
        }
    }
}
