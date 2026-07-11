import SwiftUI

@main
struct FileTransferApp: App {
    // Background URLSession wake events arrive only via a UIApplicationDelegate.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
