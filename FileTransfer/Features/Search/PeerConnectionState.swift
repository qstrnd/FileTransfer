enum PeerConnectionState: Equatable {
    case idle        // visible, not contacted
    case connecting  // invitation sent, awaiting response
    case connected   // accepted — blue ring shown
    case rejected    // declined — shake + lock animation, subtle red ring persists
}
