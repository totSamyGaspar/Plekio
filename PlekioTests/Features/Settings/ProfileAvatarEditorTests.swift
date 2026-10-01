//
//  ProfileAvatarEditorTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Testing
import Foundation
import UIKit
@testable import Plekio

@MainActor
@Suite("ProfileAvatarEditor")
struct ProfileAvatarEditorTests {

    // MARK: - Replace

    @Test("A new avatar is saved and the old one deleted")
    func replaceStoresNewAndDeletesOld() async throws {
        let photos = FakePhotoStore()
        let editor = ProfileAvatarEditor(photos: photos)

        let first = try #require(await editor.replace(nil, with: TestImages.solid(.systemRed)))
        let second = try #require(await editor.replace(first, with: TestImages.solid(.systemBlue)))

        #expect(photos.saved.keys.sorted() == [second])
        #expect(photos.deleted == [first])
    }

    @Test("If the write fails it returns nil and the old avatar stays")
    func failedWriteKeepsTheOldAvatar() async {
        let photos = FakePhotoStore(refusesWrites: true)
        let editor = ProfileAvatarEditor(photos: photos)
        let current = UUID()

        let result = await editor.replace(current, with: TestImages.solid())

        #expect(result == nil)
        #expect(photos.deleted.isEmpty)
    }

    // MARK: - Remove

    @Test("Deleting erases the file")
    func removeDeletesTheFile() async throws {
        let photos = FakePhotoStore()
        let editor = ProfileAvatarEditor(photos: photos)
        let id = try #require(await editor.replace(nil, with: TestImages.solid()))

        await editor.remove(id)

        #expect(photos.saved.isEmpty)
        #expect(photos.deleted == [id])
    }

    // MARK: - Concurrency

    @Test("The newer replacement wins in either write-completion order", arguments: [false, true])
    func overlappingReplacesLeaveOneFile(newerFinishesFirst: Bool) async throws {
        let photos = FakePhotoStore()
        let writes = ControlledAvatarWrites()
        let editor = ProfileAvatarEditor(photos: photos) { image, current, photos in
            await writes.save(image, replacing: current, in: photos)
        }

        let firstImage = TestImages.solid(.systemRed)
        let secondImage = TestImages.solid(.systemBlue)
        let first = Task { await editor.replace(nil, with: firstImage) }
        await writes.waitForWrite(0)
        let second = Task { await editor.replace(nil, with: secondImage) }
        await writes.waitForWrite(1)

        // Both replacements have advanced the generation before either write completes.
        if newerFinishesFirst {
            await writes.finish(1)
            _ = await second.value
            await writes.finish(0)
        } else {
            await writes.finish(0)
            _ = await first.value
            await writes.finish(1)
        }

        let superseded = await first.value
        let winner = try #require(await second.value)
        #expect(superseded == nil)
        #expect(Set(photos.saved.keys) == Set([winner]))
        #expect(photos.deleted.count == 1)
        #expect(!photos.deleted.contains(winner))
    }
}

/// Suspends writes cooperatively, so the test controls their overlap and completion order.
private actor ControlledAvatarWrites {
    private var nextIndex = 0
    private var pending: [Int: CheckedContinuation<Void, Never>] = [:]
    private var waitingForStart: [Int: CheckedContinuation<Void, Never>] = [:]

    func save(_ image: UIImage, replacing current: UUID?, in photos: any PhotoStoring) async -> UUID? {
        let index = nextIndex
        nextIndex += 1
        await withCheckedContinuation { continuation in
            pending[index] = continuation
            waitingForStart.removeValue(forKey: index)?.resume()
        }
        return AvatarStore.save(image, replacing: current, in: photos)
    }

    func waitForWrite(_ index: Int) async {
        guard pending[index] == nil else { return }
        await withCheckedContinuation { waitingForStart[index] = $0 }
    }

    func finish(_ index: Int) {
        pending.removeValue(forKey: index)?.resume()
    }
}
