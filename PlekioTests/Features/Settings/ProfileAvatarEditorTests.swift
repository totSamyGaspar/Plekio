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

    @Test("Of two concurrent replacements one wins, and the loser's file doesn't remain")
    func overlappingReplacesLeaveOneFile() async {
        let photos = FakePhotoStore()
        let editor = ProfileAvatarEditor(photos: photos)

        // Order is up to the scheduler; either way exactly one id and one file remain.
        async let a = editor.replace(nil, with: TestImages.solid(.systemRed))
        async let b = editor.replace(nil, with: TestImages.solid(.systemBlue))
        let results = [await a, await b].compactMap { $0 }

        #expect(results.count == 1)
        #expect(Array(photos.saved.keys) == results)
    }
}
