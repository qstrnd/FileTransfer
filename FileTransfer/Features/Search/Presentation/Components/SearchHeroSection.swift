import SwiftUI

struct SearchHeroSection: View {
    var viewModel: SearchViewModel
    var namespace: Namespace.ID
    var showRings: Bool
    var compact: Bool = false
    /// Visual treatment for the name label under the hero circle.
    /// Kept switchable for easy side-by-side comparison; pick one and drop the rest.
    var nameStyle: HeroNameStyle = .caption

    private var circleSize: CGFloat { compact ? 72 : 128 }
    private var emojiSize: CGFloat { compact ? 36 : 64 }

    var body: some View {
        VStack(spacing: nameStyle.spacing) {
            ZStack {
                if !compact && showRings {
                    PulsingRings().transition(.opacity)
                }
                Button { viewModel.goBack() } label: {
                    ZStack {
                        Circle()
                            .fill(Color.avatarBubbleBackground)
                            .frame(width: circleSize, height: circleSize)
                            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 2)
                        Text(viewModel.emoji)
                            .font(.system(size: emojiSize))
                    }
                    .matchedGeometryEffect(id: "heroCircle", in: namespace, isSource: false)
                }
                .buttonStyle(.plain)
            }
            .frame(width: circleSize, height: circleSize)

            if !compact {
                nameStyle.label(viewModel.name)
            }
        }
    }
}

// MARK: - Name label styles

enum HeroNameStyle {
    /// Plain small caption below the circle — quietest option, matches the
    /// app's existing secondary-text convention (e.g. peer names use the
    /// same idea one weight up, in `.primary`).
    case caption
    /// Small uppercase, letter-spaced label — reads as a subtle tag rather
    /// than a name, so it recedes even more than `.caption`.
    case tag
    /// Name in a soft pill below the circle — slightly more presence than
    /// the other two since it has its own background, but still small/secondary text.
    case pill

    var spacing: CGFloat {
        switch self {
        case .caption: 8
        case .tag: 6
        case .pill: 10
        }
    }

    @ViewBuilder
    func label(_ name: String) -> some View {
        switch self {
        case .caption:
            Text(name)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)

        case .tag:
            Text(name.uppercased())
                .font(.caption2.weight(.medium))
                .tracking(0.8)
                .foregroundStyle(.secondary)
                .lineLimit(1)

        case .pill:
            Text(name)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(.systemGray6), in: Capsule())
        }
    }
}

// MARK: - Previews

#Preview("Hero — caption") {
    @Previewable @Namespace var ns
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        SearchHeroSection(
            viewModel: PreviewSupport.heroPreviewVM(),
            namespace: ns, showRings: true, nameStyle: .caption
        )
    }
}

#Preview("Hero — tag") {
    @Previewable @Namespace var ns
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        SearchHeroSection(
            viewModel: PreviewSupport.heroPreviewVM(),
            namespace: ns, showRings: true, nameStyle: .tag
        )
    }
}

#Preview("Hero — pill") {
    @Previewable @Namespace var ns
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        SearchHeroSection(
            viewModel: PreviewSupport.heroPreviewVM(),
            namespace: ns, showRings: true, nameStyle: .pill
        )
    }
}

#if DEBUG
@MainActor
private enum PreviewSupport {
    private final class PreviewNearbyService: NearbySessionService {
        var delegate: (any NearbySessionServiceDelegate)?
        func start(displayName: String, deviceID: UUID) {}
        func stop() {}
        func connect(to peer: Peer, isReconnect: Bool) {}
        func send(text: String, to peer: Peer) {}
        func acceptInvitation() {}
        func declineInvitation() {}
    }

    static func heroPreviewVM() -> SearchViewModel {
        SearchViewModel(
            emoji: "🐟", name: "Fantastic Fish", deviceID: UUID(),
            service: PreviewNearbyService(),
            connectionHistory: InMemoryConnectionHistoryStore(),
            historyStore: .preview,
            onBack: {}
        )
    }
}
#endif
