import SwiftUI

// MARK: - OnboardingView

struct OnboardingView: View {
    @State private var viewModel: OnboardingViewModel
    var namespace: Namespace.ID

    /// True on the very first launch (no saved profile yet), when the tap hints
    /// and the emoji bounce are shown. False when re-editing an existing profile.
    private let isFirstLaunch: Bool

    init(onProceed: @escaping (String, String) -> Void, namespace: Namespace.ID, initialProfile: UserProfile? = nil) {
        _viewModel = State(initialValue: OnboardingViewModel(onProceed: onProceed, initialProfile: initialProfile))
        self.namespace = namespace
        self.isFirstLaunch = initialProfile == nil
    }

    @FocusState private var isNameFocused: Bool
    @State private var isEmojiPickerActive = false
    /// Latches once the user taps the icon or name, permanently dismissing the hints.
    @State private var hasEngaged = false
    /// Drives the one-time attention bounce on the emoji circle.
    @State private var iconBounce = false

    private var isKeyboardVisible: Bool { isNameFocused || isEmojiPickerActive }

    /// The first-launch "tap to change / edit" hints are shown until the user
    /// interacts with either the icon or the name.
    private var showsTapHint: Bool { isFirstLaunch && !hasEngaged }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                identitySection

                Spacer(minLength: 0)

                if !isKeyboardVisible {
                    subtitleSection
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                bottomBar
            }
            .animation(.easeOut(duration: 0.25), value: isKeyboardVisible)
        }
        .onChange(of: isKeyboardVisible) { _, visible in
            if visible { hasEngaged = true }
        }
        .overlay(alignment: .topLeading) {
            EmojiKeyboard(
                isActive: $isEmojiPickerActive,
                emoji: Binding(
                    get: { viewModel.emoji },
                    set: { viewModel.emojiSelectedByUser($0) }
                ),
                onPicked: { isNameFocused = true }
            )
                .frame(width: 1, height: 1)
                .opacity(0)
                .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isNameFocused = false
            isEmojiPickerActive = false
        }
    }

    // MARK: Identity

    private var identitySection: some View {
        VStack(spacing: 24) {
            VStack(spacing: 10) {
                Button {
                    isNameFocused = false
                    isEmojiPickerActive = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.avatarBubbleBackground)
                            .frame(width: 128, height: 128)
                            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 2)
                        Text(viewModel.emoji)
                            .font(.system(size: 64))
                    }
                    .scaleEffect(iconBounce ? 1.08 : 1)
                    .matchedGeometryEffect(id: "heroCircle", in: namespace, isSource: true)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 8) {
                TextField("Your name", text: Binding(
                        get: { viewModel.name },
                        set: { viewModel.nameEditedByUser(to: $0) }
                    ))
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.words)
                    .focused($isNameFocused)
                    .submitLabel(.done)
                    .onSubmit { isNameFocused = false }
                    .textFieldStyle(.plain)

                if showsTapHint {
                    tapHint("Tap the emoji or name to edit")
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
        }
        .padding(.horizontal, 32)
        .animation(.easeOut(duration: 0.25), value: showsTapHint)
        .onAppear {
            guard isFirstLaunch else { return }
            // A gentle, one-time bounce that draws the eye to the tappable icon,
            // then settles back to rest.
            withAnimation(.spring(response: 0.4, dampingFraction: 0.42).delay(0.35)) {
                iconBounce = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) {
                    iconBounce = false
                }
            }
        }
    }

    private func tapHint(_ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "hand.tap.fill")
            Text(text)
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(.secondary)
    }

    // MARK: Subtitle

    private var subtitleSection: some View {
        Text("Choose how this device\nis visible to others")
            .font(.title3)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 40)
            .padding(.bottom, 32)
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 0) {
            if !isKeyboardVisible {
                Button {
                    withAnimation(.spring(duration: 0.3)) { viewModel.randomize() }
                } label: {
                    iconButtonLabel("dice.fill")
                }
                .transition(.opacity.combined(with: .scale(scale: 0.8)))

                Spacer()

                if !viewModel.matchesDeviceInfo {
                    Button {
                        withAnimation(.spring(duration: 0.3)) { viewModel.useDeviceInfo() }
                    } label: {
                        Text("Device Info")
                            .font(.body)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(Color.avatarBubbleBackground, in: Capsule())
                            .shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 1)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))

                    Spacer()
                }
            } else {
                Spacer()
            }

            Button {
                viewModel.proceed()
            } label: {
                iconButtonLabel("checkmark", primary: true)
            }
            .disabled(!viewModel.canProceed)
            .opacity(viewModel.canProceed ? 1 : 0.4)
        }
        .animation(.spring(duration: 0.3), value: isKeyboardVisible)
        .animation(.spring(duration: 0.3), value: viewModel.source)
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }

    private func iconButtonLabel(_ symbol: String, primary: Bool = false) -> some View {
        Image(systemName: symbol)
            .font(.body.weight(.semibold))
            .foregroundStyle(primary ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .padding(16)
            .background(primary ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.avatarBubbleBackground), in: Circle())
            .shadow(color: .black.opacity(primary ? 0.2 : 0.07), radius: 6, x: 0, y: 1)
    }
}

#Preview {
    @Previewable @Namespace var ns
    OnboardingView(onProceed: { _, _ in }, namespace: ns)
}
