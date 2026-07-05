import ImageIO
import UIKit

/// Downsizes a contact photo before it's embedded in a vCard or persisted in
/// history, so a full-resolution Contacts photo doesn't bloat the nearby-session
/// payload or the on-disk history store.
enum ContactPhoto {
    static func downsized(_ data: Data, maxPixelSize: CGFloat = 240) -> Data? {
        let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
            return nil
        }
        let thumbOptions: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.8)
    }
}
