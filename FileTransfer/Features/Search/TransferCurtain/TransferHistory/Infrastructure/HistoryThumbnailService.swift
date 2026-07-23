import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import QuickLookThumbnailing
import UIKit

/// Generates downsampled thumbnails for images and PDFs.
/// NSCache provides memory-bounded in-process caching; thumbnails are also
/// written to disk so they survive across sessions.
///
/// @unchecked Sendable: NSCache is documented thread-safe by Apple.
final class HistoryThumbnailService: HistoryThumbnailGate, @unchecked Sendable {

    // nonisolated(unsafe): NSCache is documented thread-safe; diskRoot is write-once.
    nonisolated(unsafe) private let memCache = NSCache<NSString, NSData>()
    private let diskRoot: URL

    init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskRoot = caches.appendingPathComponent("HistoryThumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskRoot, withIntermediateDirectories: true)
        memCache.countLimit = 150
        memCache.totalCostLimit = 60 * 1_024 * 1_024  // 60 MB
    }

    // MARK: - HistoryThumbnailGate

    nonisolated func thumbnail(for url: URL) async -> Data? {
        let key = url.absoluteString as NSString
        if let hit = memCache.object(forKey: key) { return hit as Data }

        let diskURL = diskCacheURL(for: url)
        if FileManager.default.fileExists(atPath: diskURL.path(percentEncoded: false)),
           let data = try? Data(contentsOf: diskURL) {
            memCache.setObject(data as NSData, forKey: key, cost: data.count)
            return data
        }

        return await Task.detached(priority: .utility) { [weak self] in
            await self?.generate(url: url)
        }.value
    }

    nonisolated func prefetch(_ urls: [URL]) {
        for url in urls {
            let key = url.absoluteString as NSString
            guard memCache.object(forKey: key) == nil else { continue }
            Task.detached(priority: .background) { [weak self] in
                _ = await self?.thumbnail(for: url)
            }
        }
    }

    // MARK: - Private

    private nonisolated static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "gif", "tif", "tiff", "bmp", "webp"
    ]

    private nonisolated func generate(url: URL) async -> Data? {
        let ext = url.pathExtension.lowercased()
        let image: UIImage?
        if ext == "pdf" {
            image = pdfThumbnail(at: url)
        } else if Self.imageExtensions.contains(ext) {
            image = imageThumbnail(at: url)
        } else {
            image = await qlThumbnail(at: url)
        }
        guard let jpeg = image?.jpegData(compressionQuality: 0.8) else { return nil }
        let key = url.absoluteString as NSString
        memCache.setObject(jpeg as NSData, forKey: key, cost: jpeg.count)
        try? jpeg.write(to: diskCacheURL(for: url))
        return jpeg
    }

    private nonisolated func qlThumbnail(at url: URL) async -> UIImage? {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 600, height: 800),
            scale: 2,
            representationTypes: .thumbnail
        )
        return try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).uiImage
    }

    private nonisolated func imageThumbnail(at url: URL) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceShouldCache: false
        ]
        guard let src = CGImageSourceCreateWithURL(url as CFURL, options as CFDictionary) else {
            return nil
        }
        let thumbOptions: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: 600,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(src, 0, thumbOptions as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    private nonisolated func pdfThumbnail(at url: URL) -> UIImage? {
        guard let doc = PDFDocument(url: url),
              let page = doc.page(at: 0) else { return nil }
        let pageRect = page.bounds(for: .mediaBox)
        guard pageRect.width > 0, pageRect.height > 0 else { return nil }
        let scale = min(600 / pageRect.width, 800 / pageRect.height)
        let size = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.cgContext.translateBy(x: 0, y: size.height)
            ctx.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
    }

    private nonisolated func diskCacheURL(for url: URL) -> URL {
        let hash = String(format: "%08x", abs(url.absoluteString.hashValue))
        return diskRoot.appendingPathComponent("\(hash).jpg")
    }
}
