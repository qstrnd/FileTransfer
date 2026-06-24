import Foundation
import Observation

@Observable
final class SetupViewModel {
    var name = ""
    var emoji = "😊"

    var canStart: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    private let onStart: (String) -> Void

    init(onStart: @escaping (String) -> Void) {
        self.onStart = onStart
    }

    func start() {
        onStart("\(emoji) \(name)")
    }
}
