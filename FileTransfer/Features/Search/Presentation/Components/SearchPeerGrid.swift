import SwiftUI

struct SearchPeerGrid: View {
    var viewModel: SearchViewModel

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                stops: [
                    .init(color: Color(.systemGroupedBackground),               location: 0.00),
                    .init(color: Color(.systemGroupedBackground).opacity(0.85), location: 0.25),
                    .init(color: Color(.systemGroupedBackground).opacity(0.55), location: 0.55),
                    .init(color: Color(.systemGroupedBackground).opacity(0.15), location: 0.80),
                    .init(color: .clear,                                         location: 1.00),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 200)
            .allowsHitTesting(false)

            ScrollView {
                LazyVStack(spacing: 32) {
                    ForEach(viewModel.peerRows, id: \.first?.id) { row in
                        peerRowView(row)
                    }
                }
                .padding(.top, 160)
                .padding(.bottom, 40)
            }
        }
    }

    private func peerRowView(_ row: [Peer]) -> some View {
        HStack(spacing: 0) {
            if row.count == 1 {
                Spacer()
                peerCell(row[0])
                Spacer()
            } else {
                peerCell(row[0]).frame(maxWidth: .infinity)
                peerCell(row[1]).frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
    }

    private func peerCell(_ peer: Peer) -> some View {
        let state = viewModel.peerStates[peer] ?? .idle
        // Route the tap to the correct action: connected peers use disconnect,
        // all other states use connect (policy guards further).
        let action: () -> Void = (state == .connected)
            ? { viewModel.disconnect(from: peer) }
            : { viewModel.connect(to: peer) }
        return PeerCell(peer: peer, state: state, onTap: action)
            .transition(.scale(scale: 0.8).combined(with: .opacity))
    }
}
