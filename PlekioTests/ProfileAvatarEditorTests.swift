//
//  ProfileAvatarEditorTests.swift
//  PlekioTests
//
//  The avatar logic that used to live in ProfileEditView. AvatarStoreTests
//  cover the files; these cover what the screen gets back, and the case the
//  view could not handle — two changes overlapping.
//

import Testing
import Foundation
import UIKit
@testable import Plekio

@MainActor
@Suite("ProfileAvatarEditor")
struct ProfileAvatarEditorTests {

    @Test("новая аватарка сохраняется, старая удаляется")
    func replaceStoresNewAndDeletesOld() async throws {
        let photos = FakePhotoStore()
        let editor = ProfileAvatarEditor(photos: photos)

        let first = try #require(await editor.replace(nil, with: TestImages.solid(.systemRed)))
        let second = try #require(await editor.replace(first, with: TestImages.solid(.systemBlue)))

        #expect(photos.saved.keys.sorted() == [second])
        #expect(photos.deleted == [first])
    }

    @Test("если записать не удалось — nil, и старая аватарка остаётся")
    func failedWriteKeepsTheOldAvatar() async {
        let photos = FakePhotoStore(refusesWrites: true)
        let editor = ProfileAvatarEditor(photos: photos)
        let current = UUID()

        let result = await editor.replace(current, with: TestImages.solid())

        #expect(result == nil)
        #expect(photos.deleted.isEmpty)
    }

    @Test("удаление стирает файл")
    func removeDeletesTheFile() async throws {
        let photos = FakePhotoStore()
        let editor = ProfileAvatarEditor(photos: photos)
        let id = try #require(await editor.replace(nil, with: TestImages.solid()))

        await editor.remove(id)

        #expect(photos.saved.isEmpty)
        #expect(photos.deleted == [id])
    }

    @Test("из двух одновременных замен побеждает одна, файл проигравшей не остаётся")
    func overlappingReplacesLeaveOneFile() async {
        let photos = FakePhotoStore()
        let editor = ProfileAvatarEditor(photos: photos)

        // Which one starts second is up to the scheduler; either way exactly
        // one id comes back, and it is the only file left on "disk".
        async let a = editor.replace(nil, with: TestImages.solid(.systemRed))
        async let b = editor.replace(nil, with: TestImages.solid(.systemBlue))
        let results = [await a, await b].compactMap { $0 }

        #expect(results.count == 1)
        #expect(Array(photos.saved.keys) == results)
    }
}
