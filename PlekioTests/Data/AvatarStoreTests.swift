//
//  AvatarStoreTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 19.09.2026.
//

import Testing
import Foundation
import UIKit
@testable import Plekio

@Suite("AvatarStore")
struct AvatarStoreTests {

    // MARK: - Helpers

    private func scratchPath() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("PlekioAvatarTests-\(UUID().uuidString)", isDirectory: true)
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

    // MARK: - Save

    @Test("сохранённая аватарка читается обратно")
    func testSaveStoresTheImage() async throws {
        let directory = scratchPath()
        defer { remove(directory) }
        let cache = ImageCache(directory: directory)

        let id = try #require(AvatarStore.save(photo(.systemTeal), replacing: nil, in: cache))

        #expect(cache.loadDataFromDisk(for: id) != nil)
    }

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

    @Test("неудачная запись оставляет старую аватарку на месте")
    func testFailedSaveKeepsThePreviousFile() async throws {
        let directory = scratchPath()
        defer { remove(directory) }

        let working = ImageCache(directory: directory)
        let first = try #require(AvatarStore.save(photo(.systemTeal), replacing: nil, in: working))

        // A file where the directory should be, so the write must fail.
        let blocked = scratchPath()
        defer { remove(blocked) }
        try Data("in the way".utf8).write(to: blocked)

        let failed = AvatarStore.save(photo(.systemPink), replacing: first, in: ImageCache(directory: blocked))

        #expect(failed == nil)
        #expect(working.loadDataFromDisk(for: first) != nil)
    }

    // MARK: - Remove

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
