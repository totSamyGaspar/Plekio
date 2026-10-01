//
//  ProfileAvatarEditor.swift
//  Plekio
//
//  Created by Edward Gasparian on 25.09.2026.
//

import OSLog
import UIKit

/// Replaces and removes the profile avatar file, discarding writes superseded by a newer change.
@MainActor
final class ProfileAvatarEditor {

    // MARK: - Properties

    private let photos: any PhotoStoring
    private let save: Save

    /// The asynchronous write boundary; tests can hold a write in flight without sleeps.
    typealias Save = @Sendable (UIImage, UUID?, any PhotoStoring) async -> UUID?

    /// Bumped on every change so a late write knows it has been superseded.
    private var generation = 0

    // MARK: - Init

    init(
        photos: any PhotoStoring,
        save: @escaping Save = { image, current, photos in
            await Task.detached(priority: .userInitiated) {
                AvatarStore.save(image, replacing: current, in: photos)
            }.value
        }
    ) {
        self.photos = photos
        self.save = save
    }

    // MARK: - Public

    /// Stores `image` and deletes `current`. Nil when storing failed (old avatar stays)
    /// or a newer change arrived meanwhile (the new file is deleted).
    func replace(_ current: UUID?, with image: UIImage) async -> UUID? {
        generation += 1
        let mine = generation
        let photos = self.photos

        // Encoding and file I/O run off the main actor.
        let saved = await save(image, current, photos)

        guard let saved else {
            AppLog.media.error("Avatar could not be stored; the profile keeps its previous photo")
            return nil
        }
        guard mine == generation else {
            await Task.detached(priority: .utility) { AvatarStore.remove(saved, in: photos) }.value
            return nil
        }
        return saved
    }

    /// Deletes the avatar file; the caller clears the id immediately.
    func remove(_ current: UUID?) async {
        generation += 1
        let photos = self.photos
        await Task.detached(priority: .utility) { AvatarStore.remove(current, in: photos) }.value
    }
}
