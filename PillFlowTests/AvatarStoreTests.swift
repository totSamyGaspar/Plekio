//
//  AvatarStoreTests.swift
//  PillFlowTests
//
//  One rule, in both directions: a replaced avatar leaves no file behind, and a
//  failed write leaves the old one alone. Nothing else in the app points at
//  these files, so whichever way it goes wrong is invisible until the Storage
//  section in Settings starts climbing — or the profile shows a blank circle.
//

import Testing
import Foundation
import UIKit
@testable import PillFlow

@Suite("AvatarStore")
struct AvatarStoreTests {

    private func scratchPath() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("PillFlowAvatarTests-\(UUID().uuidString)", isDirectory: true)
    }

    private func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private func photo(_ color: UIColor) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        return UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64), format: format).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        }
    }

    @Test("сохранённая аватарка читается обратно")
    func testSaveStoresTheImage() async throws {
        let directory = scratchPath()
        defer { remove(directory) }
        let cache = ImageCache(directory: directory)

        let id = try #require(AvatarStore.save(photo(.systemTeal), replacing: nil, in: cache))

        #expect(cache.loadDataFromDisk(for: id) != nil)
    }

    // The leak this type exists to prevent.
    @Test("замена аватарки удаляет предыдущий файл")
    func testSaveRemovesTheReplacedFile() async throws {
        let directory = scratchPath()
        defer { remove(directory) }
        let cache = ImageCache(directory: directory)

        let first = try #require(AvatarStore.save(photo(.systemTeal), replacing: nil, in: cache))
        let second = try #require(AvatarStore.save(photo(.systemPink), replacing: first, in: cache))

        #expect(first != second)
        #expect(cache.loadDataFromDisk(for: first) == nil)
        #expect(cache.loadDataFromDisk(for: second) != nil)
    }

    // The other direction: losing the old photo AND not having a new one leaves
    // the profile pointing at nothing.
    @Test("неудачная запись оставляет старую аватарку на месте")
    func testFailedSaveKeepsThePreviousFile() async throws {
        let directory = scratchPath()
        defer { remove(directory) }

        let working = ImageCache(directory: directory)
        let first = try #require(AvatarStore.save(photo(.systemTeal), replacing: nil, in: working))

        // A plain file where the directory belongs: the write cannot be rescued.
        let blocked = scratchPath()
        defer { remove(blocked) }
        try Data("in the way".utf8).write(to: blocked)

        let failed = AvatarStore.save(photo(.systemPink), replacing: first, in: ImageCache(directory: blocked))

        #expect(failed == nil)
        #expect(working.loadDataFromDisk(for: first) != nil)
    }

    @Test("удаление без аватарки ничего не делает")
    func testRemoveWithoutAnAvatarIsHarmless() async throws {
        let directory = scratchPath()
        defer { remove(directory) }
        let cache = ImageCache(directory: directory)

        let id = try #require(AvatarStore.save(photo(.systemTeal), replacing: nil, in: cache))

        AvatarStore.remove(nil, in: cache)
        #expect(cache.loadDataFromDisk(for: id) != nil)

        AvatarStore.remove(id, in: cache)
        #expect(cache.loadDataFromDisk(for: id) == nil)
    }
}
