import UIKit
import DeviceKit

struct DeviceInfo {
    struct Identity {
        let emoji: String
        let name: String
    }

    static func current() -> Identity {
        #if targetEnvironment(macCatalyst)
        // UIDevice.current.name is the user-set Mac name, e.g. "Office MacBook".
        return Identity(emoji: "💻", name: UIDevice.current.name)
        #else
        // As of iOS 16, UIDevice.current.name returns a generic string like "iPhone"
        // without additional entitlements, so we propose the hardware model name instead.
        let emoji = UIDevice.current.userInterfaceIdiom == .pad ? "📱" : "📱"
        return Identity(emoji: emoji, name: Device.current.safeDescription)
        #endif
    }
}
