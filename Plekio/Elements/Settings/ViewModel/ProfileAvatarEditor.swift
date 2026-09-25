//
//  ProfileAvatarEditor.swift
//  Plekio
//
//  Replacing and removing the profile picture, out of ProfileEditView.
//
//  The view used to do this itself: reach into `dependencies.photoCache`, start
//  a detached task, write the file, delete the old one and log a failure. None
//  of it could be tested, and one ordering bug lived there unseen — a removal
//  tapped while a replacement was still being written came back from the dead
//  when the write finished and set the new id.
//
//  The profile itself stays where it is, in `@AppStorage` behind a binding:
//  the editor returns the id to store and the view stores it.
//

import OSLog
import UIKit

@MainActor
final class ProfileAvatarEditor {

    private let photos: any PhotoStoring

    /// Bumped on every change, so a write that finishes after a newer change
    /// (another pick, or a removal) knows it has been superseded.
    private var generation = 0

    init(photos: any PhotoStoring) {
        self.photos = photos
    }

    /// Stores `image` and deletes `current` once the new file is written.
    ///
    /// Returns the id to put in the profile, or nil when there is nothing to
    /// change: the image could not be stored (the old avatar stays), or the
    /// user changed the avatar again while this one was being written — then
    /// this file is deleted instead of being left behind.
    func replace(_ current: UUID?, with image: UIImage) async -> UUID? {
        generation += 1
        let mine = generation
        let photos = self.photos

        // Encoding and both file operations happen off the main actor; only the
        // id comes back.
        let saved = await Task.detached(priority: .userInitiated) {
            AvatarStore.save(image, replacing: current, in: photos)
        }.value

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

    /// Deletes the avatar's file. The caller clears the id at once, so the
    /// screen does not wait on the disk.
    func remove(_ current: UUID?) async {
        generation += 1
        let photos = self.photos
        await Task.detached(priority: .utility) { AvatarStore.remove(current, in: photos) }.value
    }
}
