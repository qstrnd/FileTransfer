import UIKit

/// Minimal app delegate, bridged into the SwiftUI app via
/// `@UIApplicationDelegateAdaptor`, whose only job is receiving background
/// URLSession wake events: iOS relaunches/resumes the app when queued upload
/// tasks finish, and the completion handler must be held until the reattached
/// session drains its events (see `BackgroundURLSessionUploadClient`).
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        BackgroundSessionCompletionStore.shared.store(completionHandler, forSession: identifier)
        // Recreate the upload client's session if the app was cold-launched
        // for this event, so its delegate receives the queued completions.
        if identifier == BackgroundURLSessionUploadClient.sessionIdentifier {
            BackgroundURLSessionUploadClient.awakeForBackgroundEvents()
        }
    }
}
