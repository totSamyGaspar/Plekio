//
//  ImageCache.swift
//  PillFlow
//
//  Created by Edward Gasparian on 19.06.2026.
//

import ImageIO
import OSLog
import UIKit
import UniformTypeIdentifiers

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
    // Spelled with the concrete type, not `Self`: a stored property initializer
    // cannot reference the covariant Self type.
    static let shared = ImageCache(directory: ImageCache.defaultDirectory())
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

    /// The longest edge a photo keeps on disk.
    ///
    /// The largest size anything ever draws is the top of the ladder above; a
    /// camera frame is 4032px and up. Storing that is storing eight times the
    /// pixels the app can show — around 2MB a photo instead of 400KB. The gap
    /// over 1400 leaves the zoom screen room to enlarge.
    private static let maxStoredPixelSize: CGFloat = 2048
    private static let storedQuality: CGFloat = 0.7

    /// The worst-case screen scale. Read as a constant rather than from the screen
    /// so this stays off the main actor; one ladder step of slack costs nothing.
    private static let assumedScreenScale: CGFloat = 3

    /// Photos are stored on disk (in Application Support) rather than as a
    /// SwiftData blob on MedicationItem. Keeping them out of the model avoids
    /// pulling image data on every fetch of MedicationItem, even where the image
    /// isn't shown (schedule checks, stats, etc.) — files are loaded from disk
    /// only where a UIImage is actually needed for rendering.
    private static func defaultDirectory() -> URL {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return appSupport.appendingPathComponent("MedicationImages", isDirectory: true)
    }

    /// Rooted at a directory of the caller's choosing. Production uses `shared`;
    /// tests point an instance at a temporary folder, the same way
    /// `DatabaseService(inMemoryForTesting:)` avoids the real database.
    init(directory: URL) {
        cache.countLimit = 100
        // countLimit alone bounds the number of images, not their size: 100
        // full-size photos is several gigabytes. The cost below is the decoded
        // byte count, so this is a real ceiling.
        cache.totalCostLimit = 48 * 1024 * 1024

        self.directoryURL = directory
        _ = createDirectoryIfMissing()
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
    ///
    /// The returned flag is not decoration: a record can commit while its photo
    /// does not reach the disk, and callers have to be able to say so. See
    /// `DatabaseService.persistPhotos`.
    @discardableResult
    func saveToDisk(_ data: Data, for id: UUID) -> Bool {
        let bytes = downscaled(data) ?? data
        if write(bytes, for: id) { return true }

        // The directory is created once at startup and the result discarded, so if
        // that ever failed — a first launch while the device was still locked, a
        // folder removed underneath the app — every save afterwards failed too,
        // silently and forever. Recreating it turns that from permanent into a
        // single retry.
        guard createDirectoryIfMissing() else { return false }
        return write(bytes, for: id)
    }

    /// Re-encodes an oversized photo down to `maxStoredPixelSize`.
    ///
    /// Nil when it is already small enough, or cannot be read — the caller then
    /// writes the original bytes rather than losing the photo over a resize.
    /// Always JPEG: a PNG here would be a photo saved at several times the size.
    private func downscaled(_ data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat,
              max(width, height) > Self.maxStoredPixelSize,
              let resized = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: Self.maxStoredPixelSize
              ] as CFDictionary)
        else { return nil }

        let encoded = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            encoded, UTType.jpeg.identifier as CFString, 1, nil
        ) else { return nil }

        CGImageDestinationAddImage(destination, resized, [
            kCGImageDestinationLossyCompressionQuality: Self.storedQuality
        ] as CFDictionary)

        return CGImageDestinationFinalize(destination) ? encoded as Data : nil
    }

    private func write(_ data: Data, for id: UUID) -> Bool {
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

    /// Creates the photo directory if it is not there.
    ///
    /// Returns true only when something actually changed, so a caller knows a
    /// retry is worth making: an already-present directory means the write failed
    /// for some other reason and will fail again the same way.
    @discardableResult
    private func createDirectoryIfMissing() -> Bool {
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory),
           isDirectory.boolValue {
            return false
        }

        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            return true
        } catch {
            AppLog.media.error("Photo directory unavailable: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Bytes the stored photos occupy. Walks the directory — call off the main
    /// actor.
    func diskUsageBytes() -> Int64 {
        let files = (try? fileManager.contentsOfDirectory(
            at: directoryURL, includingPropertiesForKeys: [.fileSizeKey]
        )) ?? []

        return files.reduce(0) { $0 + Self.fileSize(at: $1) }
    }

    static func fileSize(at url: URL) -> Int64 {
        Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
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
    /// Async even on a cache hit. A callback that fires synchronously there lands
    /// a @State assignment during view construction; this behaves the same either
    /// way.
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
