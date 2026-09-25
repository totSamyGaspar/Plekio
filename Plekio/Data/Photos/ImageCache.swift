//
//  ImageCache.swift
//  Plekio
//
//  Created by Edward Gasparian on 19.06.2026.
//

import ImageIO
import OSLog
import UIKit
import UniformTypeIdentifiers

/// Photo storage: an in-memory NSCache in front of files on disk.
/// `nonisolated` so disk reads really run off the main actor (module default is MainActor);
/// thread-safe because NSCache is synchronized and every other field is a `let`.
nonisolated final class ImageCache: @unchecked Sendable {

    // MARK: - Properties

    static let shared = ImageCache(directory: ImageCache.defaultDirectory())
    private let cache = NSCache<NSString, UIImage>()

    /// Ids whose file is not on disk, so scrolling rows don't re-hit the disk.
    private let knownMissing = NSCache<NSString, NSNumber>()

    private let fileManager = FileManager.default
    private let directoryURL: URL

    /// Decode sizes in pixels, smallest first; requests snap to a step so each
    /// photo is decoded at most once per drawn size instead of at full resolution.
    private static let pixelLadder: [CGFloat] = [240, 640, 1400]

    /// Longest stored edge in pixels; headroom over the ladder top is for zooming.
    private static let maxStoredPixelSize: CGFloat = 2048
    private static let storedQuality: CGFloat = 0.7

    /// Worst-case screen scale, as a constant so this stays off the main actor.
    private static let assumedScreenScale: CGFloat = 3

    /// Photos live in Application Support, not in SwiftData, so fetches never load image data.
    private static func defaultDirectory() -> URL {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return appSupport.appendingPathComponent("MedicationImages", isDirectory: true)
    }

    // MARK: - Init

    /// Production uses `shared`; tests pass a temporary folder.
    init(directory: URL) {
        cache.countLimit = 100
        // countLimit doesn't bound bytes; cost is decoded bytes, so this is a real ceiling.
        cache.totalCostLimit = 48 * 1024 * 1024

        self.directoryURL = directory
        _ = createDirectoryIfMissing()
    }

    // MARK: - Memory Cache

    private func fileURL(for id: UUID) -> URL {
        directoryURL.appendingPathComponent("\(id.uuidString).jpg")
    }

    /// The ladder step for `points`, or nil when the original is needed.
    private static func ladderStep(forPointSize points: CGFloat?) -> CGFloat? {
        guard let points, points > 0 else { return nil }
        let needed = points * assumedScreenScale
        return pixelLadder.first { $0 >= needed }
    }

    /// One cache entry per (photo, size); the full-size key is the bare id.
    private static func cacheKey(for id: UUID, step: CGFloat?) -> NSString {
        guard let step else { return id.uuidString as NSString }
        return "\(id.uuidString)@\(Int(step))" as NSString
    }

    private func set(_ image: UIImage, forKey key: NSString) {
        // Cost is decoded bytes, not the JPEG size on disk.
        let pixels = image.size.width * image.size.height * image.scale * image.scale
        cache.setObject(image, forKey: key, cost: Int(pixels) * 4)
    }

    private func get(forKey key: NSString) -> UIImage? {
        cache.object(forKey: key)
    }

    /// Every key a photo can be cached under, since NSCache cannot be enumerated.
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

    /// Remembered between calls; checked first because ImageIO logs an error per missing path.
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

    /// Saves JPEG data under `id`. Returns whether it reached disk; callers must report failure.
    @discardableResult
    func saveToDisk(_ data: Data, for id: UUID) -> Bool {
        let bytes = downscaled(data) ?? data
        if write(bytes, for: id) { return true }

        // The directory may have failed to create at launch or been removed: recreate and retry once.
        guard createDirectoryIfMissing() else { return false }
        return write(bytes, for: id)
    }

    /// Re-encodes an oversized photo as JPEG at `maxStoredPixelSize`.
    /// Nil when already small enough or unreadable; the caller then writes the original.
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
            // Every decoded size in memory is now stale.
            evict(id)
            return true
        } catch {
            AppLog.media.error("Failed to save photo to disk: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// True only if the directory was created, i.e. a retry is worth making.
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

    /// Bytes the stored photos occupy. Walks the directory; call off the main actor.
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

    // MARK: - Async Loading

    /// Memory cache first, then a read and decode off the main thread. Async even
    /// on a hit, so it never assigns @State during view construction.
    /// - Parameter targetPointSize: longest drawn edge in points; nil for the original.
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

    /// Decodes straight to the requested size through ImageIO, so no full-size bitmap is allocated.
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
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            // Honour EXIF orientation, or portrait shots come back sideways.
            kCGImageSourceCreateThumbnailWithTransform: true,
            // Decode now, off the main thread, not lazily on first draw.
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        // Debug level: a corrupt file, not an app error, and this runs per row.
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            AppLog.media.debug("Photo could not be decoded: \(id.uuidString, privacy: .public)")
            return nil
        }
        return UIImage(cgImage: thumbnail)
    }
}
