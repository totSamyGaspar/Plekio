//
//  AvatarStore.swift
//  Plekio
//
//  Created by Edward Gasparian on 19.09.2026.
//

import UIKit

/// Stores the profile picture; replacing one must delete the old file or it leaks.
nonisolated enum AvatarStore {

    // MARK: - Public

    /// Writes `image`, then removes `previous`. Nil on failure, with `previous` kept.
    /// Touches the filesystem; call off the main actor.
    @discardableResult
    static func save(
        _ image: UIImage,
        replacing previous: UUID?,
        in cache: any PhotoStoring
    ) -> UUID? {
        // PNG fallback: jpegData returns nil for an image with no CGImage.
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
