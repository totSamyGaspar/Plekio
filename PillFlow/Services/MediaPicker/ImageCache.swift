//
//  ImageCache.swift
//  PillFlow
//
//  Created by Edward Gasparian on 19.06.2026.
//

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
    private let fileManager = FileManager.default
    private let directoryURL: URL

    private init() {
        cache.countLimit = 100

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

    private func set(_ image: UIImage, forKey key: UUID) {
        cache.setObject(image, forKey: key.uuidString as NSString)
    }

    private func get(forKey key: UUID) -> UIImage? {
        return cache.object(forKey: key.uuidString as NSString)
    }

    // MARK: - Disk Storage

    /// Saves already-compressed photo data (JPEG) to a file named by the
    /// medication's id.
    @discardableResult
    func saveToDisk(_ data: Data, for id: UUID) -> Bool {
        do {
            try data.write(to: fileURL(for: id), options: .atomic)
            // The file changed — the previously decoded image in memory is now stale.
            cache.removeObject(forKey: id.uuidString as NSString)
            return true
        } catch {
            AppLog.media.error("Failed to save photo to disk: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func loadDataFromDisk(for id: UUID) -> Data? {
        try? Data(contentsOf: fileURL(for: id))
    }

    func deleteFromDisk(for id: UUID) {
        try? fileManager.removeItem(at: fileURL(for: id))
        cache.removeObject(forKey: id.uuidString as NSString)
    }

    // MARK: - Shared Async Loading

    /// The single entry point for loading a photo: memory cache first, then a read
    /// and decode off the main thread on a miss.
    ///
    /// This used to be a callback that fired synchronously on a cache hit, so a
    /// @State assignment could land during view construction. The async version
    /// behaves the same either way.
    func image(for id: UUID) async -> UIImage? {
        if let cached = get(forKey: id) { return cached }

        let decoded = await Task.detached(priority: .userInitiated) { [self] in
            loadDataFromDisk(for: id).flatMap { UIImage(data: $0) }
        }.value

        if let decoded { set(decoded, forKey: id) }
        return decoded
    }
}
