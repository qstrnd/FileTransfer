import SwiftUI

struct SearchPeerGrid: View {
    var viewModel: SearchViewModel
    var cellSize: CGFloat = 100
    var columnsPerRow: Int = 2
    var topPadding: CGFloat = 160
    var gradientHeight: CGFloat = 200
    /// Extra bottom space below the last row. Set to ≥208 in portrait to keep
    /// the bottom rows clear of the curtain peek.
    var bottomInset: CGFloat = 224
    /// When true, a row with a single cell is centred horizontally.
    /// Pass false in landscape where left-aligned is intentional.
    var centerSingleItem: Bool = true

    private var rows: [[Peer]] {
        stride(from: 0, to: viewModel.discoveredPeers.count, by: columnsPerRow).map { i in
            Array(viewModel.discoveredPeers[i..<min(i + columnsPerRow, viewModel.discoveredPeers.count)])
        }
    }

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
            .frame(height: gradientHeight)
            .allowsHitTesting(false)

            ScrollView {
                LazyVStack(spacing: 32) {
                    ForEach(rows, id: \.first?.id) { row in
                        peerRowView(row)
                    }
                }
                .padding(.top, topPadding)
                .padding(.bottom, bottomInset)
            }
        }
    }

    @ViewBuilder
    private func peerRowView(_ row: [Peer]) -> some View {
        HStack(spacing: 0) {
            if centerSingleItem && row.count == 1 {
                Spacer()
                peerCell(row[0])
                Spacer()
            } else {
                ForEach(0..<columnsPerRow, id: \.self) { col in
                    Group {
                        if col < row.count {
                            peerCell(row[col])
                        } else {
                            Color.clear
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func peerCell(_ peer: Peer) -> some View {
        let state = viewModel.peerStates[peer] ?? .idle
        let action: () -> Void = (state == .connected)
            ? { viewModel.disconnect(from: peer) }
            : { viewModel.connect(to: peer) }
        return PeerCell(peer: peer, state: state, onTap: action, size: cellSize)
            .transition(.scale(scale: 0.8).combined(with: .opacity))
    }
}
