import ActivityKit
import SwiftUI
import WidgetKit

/// Lock-screen banner + Dynamic Island presentation for an in-flight transfer.
struct TransferLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TransferActivityAttributes.self) { context in
            LockScreenTransferView(context: context)
                .padding(16)
                .activityBackgroundTint(Color(.systemBackground).opacity(0.85))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: phaseIcon(for: context.state.phase, direction: context.attributes.direction))
                        .font(.title2)
                        .foregroundStyle(phaseTint(for: context.state.phase))
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.attributes.peerName)
                        .font(.caption)
                        .lineLimit(1)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        Text(phaseTitle(for: context))
                            .font(.callout.weight(.medium))
                        if isRunning(context.state.phase) {
                            ProgressView(value: context.state.progress)
                                .tint(.blue)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: phaseIcon(for: context.state.phase, direction: context.attributes.direction))
                    .foregroundStyle(phaseTint(for: context.state.phase))
            } compactTrailing: {
                if isRunning(context.state.phase) {
                    ProgressView(value: context.state.progress)
                        .progressViewStyle(.circular)
                        .tint(.blue)
                } else {
                    Image(systemName: context.state.phase == .success ? "checkmark" : "xmark")
                        .foregroundStyle(phaseTint(for: context.state.phase))
                }
            } minimal: {
                Image(systemName: phaseIcon(for: context.state.phase, direction: context.attributes.direction))
                    .foregroundStyle(phaseTint(for: context.state.phase))
            }
        }
    }
}

// MARK: - Lock screen

private struct LockScreenTransferView: View {
    let context: ActivityViewContext<TransferActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: phaseIcon(for: context.state.phase, direction: context.attributes.direction))
                    .font(.title3)
                    .foregroundStyle(phaseTint(for: context.state.phase))
                Text(phaseTitle(for: context))
                    .font(.callout.weight(.semibold))
                Spacer()
                Text(context.attributes.peerName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if isRunning(context.state.phase) {
                ProgressView(value: context.state.progress)
                    .tint(.blue)
                Text("\(Int(context.state.progress * 100))% · \(context.state.completedItems)/\(context.attributes.totalItems) item\(context.attributes.totalItems == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Shared presentation helpers

private func isRunning(_ phase: TransferActivityAttributes.ContentState.Phase) -> Bool {
    phase == .sending || phase == .receiving
}

private func phaseTitle(for context: ActivityViewContext<TransferActivityAttributes>) -> String {
    switch context.state.phase {
    case .sending:   "Sending \(context.attributes.totalItems) item\(context.attributes.totalItems == 1 ? "" : "s")"
    case .receiving: "Receiving \(context.attributes.totalItems) item\(context.attributes.totalItems == 1 ? "" : "s")"
    case .success:   context.attributes.direction == .send ? "Sent!" : "Received!"
    case .failure:   "Transfer failed"
    }
}

private func phaseIcon(for phase: TransferActivityAttributes.ContentState.Phase, direction: TransferActivityAttributes.Direction) -> String {
    switch phase {
    case .sending, .receiving:
        direction == .send ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
    case .success:
        "checkmark.circle.fill"
    case .failure:
        "xmark.circle.fill"
    }
}

private func phaseTint(for phase: TransferActivityAttributes.ContentState.Phase) -> Color {
    switch phase {
    case .sending, .receiving: .blue
    case .success:             .green
    case .failure:             .red
    }
}
