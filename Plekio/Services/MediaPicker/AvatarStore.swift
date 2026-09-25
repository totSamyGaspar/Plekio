//
//  AvatarStore.swift
//  Plekio
//

import UIKit

/// Storing and replacing the profile picture.
///
/// Its own type for one invariant: replacing an avatar has to delete the one it
/// replaces. Nothing else in the app references that file, so a forgotten
/// delete leaks a photo on every change — and since the Storage section in
/// Settings now counts photo bytes, the user would watch it grow.
nonisolated enum AvatarStore {

    /// Writes `image` and removes `previous` once the write has succeeded.
    ///
    /// Nil when the image cannot be encoded or stored. `previous` is left in
    /// place in that case: deleting it would leave the profile pointing at a
    /// file that no longer exists, which is worse than an unchanged avatar.
    ///
    /// Touches the filesystem — call off the main actor.
    @discardableResult
    static func save(
        _ image: UIImage,
        replacing previous: UUID?,
        in cache: any PhotoStoring
    ) -> UUID? {
        // pngData is the fallback: jpegData returns nil for an image with no
        // CGImage behind it. ImageCache caps the stored size on the way in.
        guard let data = image.jpegData(compressionQuality: 0.7) ?? image.pngData() else {
            return nil
        }

        let id = UUID()
        guard cache.saveToDisk(data, for: id) else { return nil }

        remove(previous, in: cache)
        return id
    }

    static func remove(_ id: UUID?, in cache: any PhotoStoring) {
        guard let id else { return }
        cache.deleteFromDisk(for: id)
    }
}
