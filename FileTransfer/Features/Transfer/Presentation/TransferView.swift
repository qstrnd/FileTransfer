import SwiftUI

struct TransferView: View {
    var viewModel: TransferViewModel
    @State private var messageText = ""
    @State private var showMessageAlert = false

    var body: some View {
        NavigationStack {
            List {
                nearbyDevicesSection
                connectedSection
                if !viewModel.receivedMessages.isEmpty {
                    receivedSection
                }
            }
            .navigationTitle("FileTransfer")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Stop", role: .destructive) { viewModel.stop() }
                }
            }
            .alert("Connection Request", isPresented: Binding(
                get: { viewModel.pendingInvitationFrom != nil },
                set: { _ in }
            )) {
                Button("Accept") { viewModel.acceptInvitation() }
                Button("Decline", role: .cancel) { viewModel.declineInvitation() }
            } message: {
                if let peer = viewModel.pendingInvitationFrom {
                    Text("\(peer.displayName) wants to connect")
                }
            }
            .alert("Message Received", isPresented: $showMessageAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                if let msg = viewModel.lastReceivedMessage {
                    Text("From \(msg.senderName):\n\(msg.text)")
                }
            }
            .onChange(of: viewModel.lastReceivedMessage) {
                showMessageAlert = true
            }
        }
    }

    private var nearbyDevicesSection: some View {
        Section("Nearby Devices") {
            if viewModel.discoveredPeers.isEmpty {
                Label("Scanning for peers…", systemImage: "magnifyingglass")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.discoveredPeers) { peer in
                    HStack {
                        Text(peer.displayName)
                        Spacer()
                        Button("Connect") { viewModel.connect(to: peer) }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                }
            }
        }
    }

    private var connectedSection: some View {
        Section("Connected") {
            if viewModel.connectedPeers.isEmpty {
                Text("No active connections").foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.connectedPeers) { peer in
                    PeerSendRow(peer: peer, messageText: $messageText) { text in
                        viewModel.send(text: text, to: peer)
                    }
                }
            }
        }
    }

    private var receivedSection: some View {
        Section("Received") {
            ForEach(viewModel.receivedMessages) { msg in
                VStack(alignment: .leading, spacing: 2) {
                    Text(msg.senderName).font(.caption).foregroundStyle(.secondary)
                    Text(msg.text)
                }
            }
        }
    }
}

private struct PeerSendRow: View {
    let peer: Peer
    @Binding var messageText: String
    let onSend: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(peer.displayName, systemImage: "wifi").font(.headline)
            HStack {
                TextField("Message to send…", text: $messageText)
                    .textFieldStyle(.roundedBorder)
                Button("Send") {
                    onSend(messageText)
                    messageText = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(messageText.isEmpty)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    TransferView(viewModel: TransferViewModel(
        service: MultipeerNearbyService(),
        onStop: {}
    ))
}
