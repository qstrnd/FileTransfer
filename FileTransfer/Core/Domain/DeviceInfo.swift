import UIKit

struct DeviceInfo {
    struct Identity {
        let emoji: String
        let name: String
    }

    static func current() -> Identity {
        // UIDevice.current.name is the user-set device name:
        // "Andy's iPhone", "Office MacBook", etc.
        #if targetEnvironment(macCatalyst)
        return Identity(emoji: "💻", name: UIDevice.current.name)
        #else
        let emoji = UIDevice.current.userInterfaceIdiom == .pad ? "📱" : "📱"
        return Identity(emoji: emoji, name: UIDevice.current.name)
        #endif
    }
}
