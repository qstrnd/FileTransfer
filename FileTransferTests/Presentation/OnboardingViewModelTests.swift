import Testing
import Foundation
@testable import FileTransfer

@MainActor
struct OnboardingDeviceInfoTests {

    private let device = DeviceInfo.Identity(emoji: "💻", name: "Andy's Mac")

    private func makeVM(initialProfile: UserProfile? = nil) -> OnboardingViewModel {
        OnboardingViewModel(
            onProceed: { _, _ in },
            initialProfile: initialProfile,
            deviceInfo: { self.device }
        )
    }

    @Test func freshOnboardingStartsMatchingDeviceInfo() {
        let vm = makeVM()
        #expect(vm.name == device.name)
        #expect(vm.emoji == device.emoji)
        #expect(vm.matchesDeviceInfo)
    }

    @Test func returningWithProfileEqualToDeviceInfoStillMatches() {
        // The bug: coming back from SearchView forces source == .custom, but if
        // the saved profile already equals the device identity the "Device Info"
        // button must stay hidden.
        let vm = makeVM(initialProfile: UserProfile(emoji: device.emoji, name: device.name))
        #expect(vm.source == .custom)
        #expect(vm.matchesDeviceInfo)
    }

    @Test func returningWithProfileEqualToDeviceInfoIgnoringWhitespaceMatches() {
        let vm = makeVM(initialProfile: UserProfile(emoji: device.emoji, name: "  Andy's Mac  "))
        #expect(vm.matchesDeviceInfo)
    }

    @Test func differentNameDoesNotMatch() {
        let vm = makeVM(initialProfile: UserProfile(emoji: device.emoji, name: "Something Else"))
        #expect(!vm.matchesDeviceInfo)
    }

    @Test func differentEmojiDoesNotMatch() {
        let vm = makeVM(initialProfile: UserProfile(emoji: "🦊", name: device.name))
        #expect(!vm.matchesDeviceInfo)
    }

    @Test func editingNameBreaksTheMatch() {
        let vm = makeVM()
        #expect(vm.matchesDeviceInfo)
        vm.nameEditedByUser(to: "Custom Name")
        #expect(!vm.matchesDeviceInfo)
    }

    @Test func useDeviceInfoRestoresTheMatch() {
        let vm = makeVM(initialProfile: UserProfile(emoji: "🦊", name: "Custom Name"))
        #expect(!vm.matchesDeviceInfo)
        vm.useDeviceInfo()
        #expect(vm.matchesDeviceInfo)
        #expect(vm.name == device.name)
        #expect(vm.emoji == device.emoji)
    }
}
