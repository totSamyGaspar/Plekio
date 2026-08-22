//
//  ImageCache.swift
//  PillFlow
//
//  Created by Edward Gasparian on 19.06.2026.
//

import UIKit

final class ImageCache {
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

    func set(_ image: UIImage, forKey key: UUID) {
        cache.setObject(image, forKey: key.uuidString as NSString)
    }

    func get(forKey key: UUID) -> UIImage? {
        return cache.object(forKey: key.uuidString as NSString)
    }

    // MARK: - Disk Storage

    /// Saves already-compressed photo data (JPEG) to a file named by the medication's id.
    @discardableResult
    func saveToDisk(_ data: Data, for id: UUID) -> Bool {
        do {
            try data.write(to: fileURL(for: id), options: .atomic)
            // The file changed — the previously decoded image in memory is now stale.
            cache.removeObject(forKey: id.uuidString as NSString)
            return true
        } catch {
            print("🚨 Failed to save medication photo to disk: \(error)")
            return false
        }
    }

    func loadDataFromDisk(for id: UUID) -> Data? {
        try? Data(contentsOf: fileURL(for: id))
    }

    /// Deletes the photo file from disk (e.g. when a medication is deleted, or via an explicit "Delete" in the UI).
    func deleteFromDisk(for id: UUID) {
        try? fileManager.removeItem(at: fileURL(for: id))
        cache.removeObject(forKey: id.uuidString as NSString)
    }

    // MARK: - Shared Async Loading
    //
    // Single entry point for loading a medication photo: checks the in-memory
    // cache first, then decodes the JPEG data off the main thread on a cache
    // miss. Loading and rendering should both go through this method rather
    // than duplicating the cache-check/decode logic per view.
    func loadAsync(for id: UUID, completion: @escaping (UIImage?) -> Void) {
        if let cached = get(forKey: id) {
            completion(cached)
            return
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let decoded = self.loadDataFromDisk(for: id).flatMap { UIImage(data: $0) }
            if let decoded {
                self.set(decoded, forKey: id)
            }
            DispatchQueue.main.async {
                completion(decoded)
            }
        }
    }
}
