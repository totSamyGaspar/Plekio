//
//  ImageCache.swift
//  PillFlow
//
//  Created by Edward Gasparian on 19.06.2026.
//

import ImageIO
import OSLog
import UIKit

/// Photo storage: an in-memory NSCache in front of files on disk.
///
/// `nonisolated` is required here. The project builds with default main-actor
/// isolation (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`), so the whole module
/// is implicitly `@MainActor`; `Sendable` alone is not enough, it is about
/// passing values, not isolation. Without `nonisolated` the `Task.detached`
/// disk read either warned or silently hopped back onto the main thread through
/// an implicit `await`, defeating the point of reading files off it.
///
/// Thread safety is by construction: `NSCache` synchronizes itself and every
/// other field is an immutable `let`, so there is no shared mutable state.
nonisolated final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()

    /// Ids whose file is not on disk.
    ///
    /// A photo id can outlive its file — an entry restored onto a fresh install,
    /// a file removed while its id stayed on the model. Nothing about a missing
    /// file changes between one appearance of a row and the next, but `.task`
    /// runs again every time the row scrolls back in, so without this each of
    /// those rows hits the disk on every pass. An NSCache rather than a Set: it
    /// is synchronized like the one above, and evicting an entry only costs one
    /// extra look.
    private let knownMissing = NSCache<NSString, NSNumber>()

    private let fileManager = FileManager.default
    private let directoryURL: URL

    /// The sizes a photo is ever decoded to, in pixels, smallest first.
    ///
    /// A camera photo is around 4000px on its long edge. Drawing that into a 68pt
    /// thumbnail meant decoding ~48MB and handing the compositor a texture 60×
    /// bigger than the space it fills — which is what made the diary feed stutter
    /// as photo rows came into view, and what filled the cache with a handful of
    /// full-size frames. Requests are snapped to a step instead, so the same photo
    /// is decoded at most once per size it is actually drawn at.
    private static let pixelLadder: [CGFloat] = [240, 640, 1400]

    /// The worst-case screen scale. Read as a constant rather than from the screen
    /// so this stays off the main actor; one ladder step of slack costs nothing.
    private static let assumedScreenScale: CGFloat = 3

    private init() {
        cache.countLimit = 100
        // countLimit alone bounds the number of images, not their size: 100
        // full-size photos is several gigabytes. The cost below is the decoded
        // byte count, so this is a real ceiling.
        cache.totalCostLimit = 48 * 1024 * 1024

        // Photos are stored on disk (in Application Support) rather than as a
        // SwiftData blob on MedicationItem. Keeping them out of the model avoids
        // pulling image data on every fetch of MedicationItem, even where the
        // image isn't shown (schedule checks, stats, etc.) — files are loaded
        // from disk only where a UIImage is actually needed for rendering.
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let dir = appSupport.appendingPathComponent("MedicationImages", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        self.directoryURL = dir
    }

    private func fileURL(for id: UUID) -> URL {
        directoryURL.appendingPathComponent("\(id.uuidString).jpg")
    }

    /// The ladder step a view of `points` needs, or nil when it wants the
    /// original — a zoom screen, or anything bigger than the largest step.
    private static func ladderStep(forPointSize points: CGFloat?) -> CGFloat? {
        guard let points, points > 0 else { return nil }
        let needed = points * assumedScreenScale
        return pixelLadder.first { $0 >= needed }
    }

    /// One cache entry per (photo, size): the full-size key keeps its old form so
    /// nothing else has to know about the ladder.
    private static func cacheKey(for id: UUID, step: CGFloat?) -> NSString {
        guard let step else { return id.uuidString as NSString }
        return "\(id.uuidString)@\(Int(step))" as NSString
    }

    private func set(_ image: UIImage, forKey key: NSString) {
        // Decoded bytes, which is what the ceiling is meant to bound — not the
        // size of the JPEG on disk.
        let pixels = image.size.width * image.size.height * image.scale * image.scale
        cache.setObject(image, forKey: key, cost: Int(pixels) * 4)
    }

    private func get(forKey key: NSString) -> UIImage? {
        cache.object(forKey: key)
    }

    /// Every key a photo can be cached under. NSCache cannot be enumerated, and a
    /// photo that was replaced must not keep serving its old thumbnails.
    private static func allCacheKeys(for id: UUID) -> [NSString] {
        [cacheKey(for: id, step: nil)] + pixelLadder.map { cacheKey(for: id, step: $0) }
    }

    private func evict(_ id: UUID) {
        for key in Self.allCacheKeys(for: id) {
            cache.removeObject(forKey: key)
        }
        // A photo that was just written is no longer missing.
        knownMissing.removeObject(forKey: id.uuidString as NSString)
    }

    /// Whether the file is there at all, remembered between calls.
    ///
    /// Checked before anything opens the file: handing a path that does not exist
    /// to ImageIO makes it log an error of its own per attempt, which on a
    /// scrolling feed of entries whose photos are gone is hundreds of console
    /// writes — slow in a debug session, and drowning out real messages.
    private func fileIsMissing(_ id: UUID) -> Bool {
        let key = id.uuidString as NSString
        if knownMissing.object(forKey: key) != nil { return true }

        guard fileManager.fileExists(atPath: fileURL(for: id).path) else {
            knownMissing.setObject(true as NSNumber, forKey: key)
            return true
        }
        return false
    }

    // MARK: - Disk Storage

    /// Saves already-compressed photo data (JPEG) to a file named by the
    /// medication's id.
    @discardableResult
    func saveToDisk(_ data: Data, for id: UUID) -> Bool {
        do {
            try data.write(to: fileURL(for: id), options: .atomic)
            // The file changed — every decoded size of it in memory is now stale.
            evict(id)
            return true
        } catch {
            AppLog.media.error("Failed to save photo to disk: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func loadDataFromDisk(for id: UUID) -> Data? {
        guard !fileIsMissing(id) else { return nil }
        return try? Data(contentsOf: fileURL(for: id))
    }

    func deleteFromDisk(for id: UUID) {
        try? fileManager.removeItem(at: fileURL(for: id))
        evict(id)
    }

    // MARK: - Shared Async Loading

    /// The single entry point for loading a photo: memory cache first, then a read
    /// and decode off the main thread on a miss.
    ///
    /// This used to be a callback that fired synchronously on a cache hit, so a
    /// @State assignment could land during view construction. The async version
    /// behaves the same either way.
    ///
    /// - Parameter targetPointSize: the longest edge the image will be drawn at,
    ///   in points. The photo is decoded to the nearest size at or above that
    ///   instead of at full resolution. Pass nil only where the original really is
    ///   needed — the zoom screen.
    func image(for id: UUID, targetPointSize: CGFloat? = nil) async -> UIImage? {
        let step = Self.ladderStep(forPointSize: targetPointSize)
        let key = Self.cacheKey(for: id, step: step)

        if let cached = get(forKey: key) { return cached }

        let decoded = await Task.detached(priority: .userInitiated) { [self] in
            decodeFromDisk(id: id, maxPixelSize: step)
        }.value

        if let decoded { set(decoded, forKey: key) }
        return decoded
    }

    /// Decodes straight to the requested size through ImageIO, so the full-size
    /// bitmap never exists: `UIImage(data:)` followed by a resize would allocate
    /// it first, which is the cost being avoided here.
    private func decodeFromDisk(id: UUID, maxPixelSize: CGFloat?) -> UIImage? {
        guard !fileIsMissing(id) else { return nil }

        guard let maxPixelSize else {
            return loadDataFromDisk(for: id).flatMap { UIImage(data: $0) }
        }

        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(fileURL(for: id) as CFURL, sourceOptions) else {
            return nil
        }

        let options: [CFString: Any] = [
            // Always: a photo without an embedded thumbnail must still come back.
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            // Honour the EXIF orientation, or portrait shots come back sideways.
            kCGImageSourceCreateThumbnailWithTransform: true,
            // Decode here, on this background task, rather than lazily on the
            // main thread the first time the image is drawn.
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        // Logged at debug level: the file exists but will not decode, which is a
        // corrupt file rather than an app error, and a log line here is on the
        // path of every row that shows it.
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            AppLog.media.debug("Photo could not be decoded: \(id.uuidString, privacy: .public)")
            return nil
        }
        return UIImage(cgImage: thumbnail)
    }
}
