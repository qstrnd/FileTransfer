import Testing
@testable import FileTransfer

struct OnboardingViewModelTests {

    // MARK: - isValidEmoji

    @Test func singleEmoji_isValid() {
        #expect(OnboardingViewModel.isValidEmoji("🐟"))
        #expect(OnboardingViewModel.isValidEmoji("🦁"))
        #expect(OnboardingViewModel.isValidEmoji("🌟"))
        #expect(OnboardingViewModel.isValidEmoji("💻"))
        #expect(OnboardingViewModel.isValidEmoji("📱"))
    }

    @Test func zwjSequence_isValid() {
        #expect(OnboardingViewModel.isValidEmoji("👨‍👩‍👧‍👦")) // family ZWJ
        #expect(OnboardingViewModel.isValidEmoji("👩‍💻"))       // woman technologist
    }

    @Test func keycapEmoji_isValid() {
        #expect(OnboardingViewModel.isValidEmoji("1️⃣"))  // digit + variation + combining
        #expect(OnboardingViewModel.isValidEmoji("#️⃣"))
    }

    @Test func emojiWithVariationSelector_isValid() {
        #expect(OnboardingViewModel.isValidEmoji("©️")) // copyright + variation selector
        #expect(OnboardingViewModel.isValidEmoji("☀️"))
    }

    @Test func plainText_isInvalid() {
        #expect(!OnboardingViewModel.isValidEmoji("a"))
        #expect(!OnboardingViewModel.isValidEmoji("hello"))
        #expect(!OnboardingViewModel.isValidEmoji("A"))
    }

    @Test func bareDigit_isInvalid() {
        // "1" has isEmoji = true but no presentation and no modifiers → rejected
        #expect(!OnboardingViewModel.isValidEmoji("1"))
        #expect(!OnboardingViewModel.isValidEmoji("0"))
        #expect(!OnboardingViewModel.isValidEmoji("#"))
    }

    @Test func emptyString_isInvalid() {
        #expect(!OnboardingViewModel.isValidEmoji(""))
    }

    @Test func whitespace_isInvalid() {
        #expect(!OnboardingViewModel.isValidEmoji(" "))
        #expect(!OnboardingViewModel.isValidEmoji("\n"))
    }
}
