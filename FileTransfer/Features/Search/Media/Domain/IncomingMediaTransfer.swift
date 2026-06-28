import Foundation

struct IncomingMediaTransfer: Identifiable {
    let id: String
    let senderName: String
    /// Number of user-visible items (not file count — LP sends 2 files per 1 item).
    let totalCount: Int
    private(set) var slots: [Int: ReceivedSlot] = [:]

    // MARK: - Progress

    /// Number of logical items whose primary file (still or regular) has arrived.
    var receivedCount: Int { slots.count }

    /// True when every logical item — and every LP companion video — has arrived.
    var isComplete: Bool {
        slots.count >= totalCount && slots.values.allSatisfy(\.isComplete)
    }

    // MARK: - Mutation

    mutating func add(url: URL, at index: Int, kind: MediaFileKind, fileName: String?) {
        switch kind {
        case .regular:
            slots[index] = ReceivedSlot(kind: .regular(url), fileName: fileName)

        case .livePhotoStill:
            let existingVideo: URL?
            if case .livePhoto(_, let v) = slots[index]?.kind { existingVideo = v } else { existingVideo = nil }
            slots[index] = ReceivedSlot(kind: .livePhoto(still: url, video: existingVideo), fileName: fileName)

        case .livePhotoVideo:
            if slots[index] != nil {
                slots[index]?.setLPVideo(url)
            } else {
                // Companion arrived before still — hold it until the still comes.
                slots[index] = ReceivedSlot(kind: .livePhoto(still: nil, video: url), fileName: nil)
            }
        }
    }

    // MARK: - Build result

    /// Call only when `isComplete`. Assembles the ordered `ReceivedMediaItem` array.
    func buildItems(transferID: String) -> [ReceivedMediaItem] {
        let dateStr = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: Date())
        }()
        let hash = String(transferID.prefix(6))

        return (0..<totalCount).compactMap { idx in
            guard let slot = slots[idx] else { return nil }
            let count = idx + 1
            switch slot.kind {
            case .regular(let url):
                let ext = url.pathExtension.lowercased()
                let name = slot.fileName.map { "\($0).\(ext)" }
                    ?? "shared-photo-\(dateStr)-\(hash)-\(count).\(ext)"
                let isVideo = videoExtensions.contains(ext)
                return ReceivedMediaItem(fileURL: url, isVideo: isVideo, livePhotoVideoURL: nil, fileName: name)

            case .livePhoto(let still?, let video?):
                let ext = still.pathExtension.lowercased()
                let name = slot.fileName.map { "\($0).\(ext)" }
                    ?? "shared-photo-\(dateStr)-\(hash)-\(count).\(ext)"
                return ReceivedMediaItem(fileURL: still, isVideo: false, livePhotoVideoURL: video, fileName: name)

            case .livePhoto:
                return nil  // incomplete — guarded by isComplete above
            }
        }
    }
}

// MARK: - ReceivedSlot

struct ReceivedSlot {
    var kind: SlotKind
    var fileName: String?

    var isComplete: Bool { kind.isComplete }

    mutating func setLPVideo(_ url: URL) {
        if case .livePhoto(let still, _) = kind {
            kind = .livePhoto(still: still, video: url)
        }
    }

    enum SlotKind {
        case regular(URL)
        case livePhoto(still: URL?, video: URL?)

        var isComplete: Bool {
            switch self {
            case .regular: true
            case .livePhoto(let s, let v): s != nil && v != nil
            }
        }
    }
}

private let videoExtensions: Set<String> = ["mp4", "mov", "m4v", "avi"]
