import SwiftUI

/// "Searching for other devices" label with a cyclic oblique shimmer.
///
/// Uses `TimelineView(.animation)` for reliable per-frame phase updates —
/// SwiftUI does not interpolate `@State`-driven gradient stops frame-by-frame.
struct SearchingText: View {
    private static let cycleDuration: TimeInterval = 2.8

    var body: some View {
        TimelineView(.animation) { context in
            let phase = shimmerPhase(at: context.date)
            Text("Searching\nfor other devices\non the network...")
                .font(.system(size: 30, weight: .bold))
                .multilineTextAlignment(.leading)
                .foregroundStyle(
                    LinearGradient(
                        stops: [
                            .init(color: Color.secondary,            location: phase - 0.25),
                            .init(color: Color(UIColor.systemGray5), location: phase),
                            .init(color: Color.secondary,            location: phase + 0.25),
                        ],
                        startPoint: UnitPoint(x: 0, y: 0.3),
                        endPoint:   UnitPoint(x: 1, y: 0.7)
                    )
                )
        }
    }

    private func shimmerPhase(at date: Date) -> CGFloat {
        let t = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: Self.cycleDuration) / Self.cycleDuration
        return CGFloat(t) * 1.6 - 0.3
    }
}
