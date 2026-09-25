//
//  ImageCacheTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 14.09.2026.
//

import Testing
import Foundation
import UIKit
@testable import Plekio

@MainActor
@Suite("ImageCache disk storage")
struct ImageCacheTests {

    // MARK: - Helpers

    /// A temp path that does not exist yet.
    private func scratchPath() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("PlekioImageCacheTests-\(UUID().uuidString)", isDirectory: true)
    }

    private func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private var samplePhoto: Data { Data("not really a jpeg, but bytes are bytes".utf8) }

    // MARK: - Save and delete

    @Test("сохранение в существующую папку удаётся, и байты читаются обратно")
    func testSaveAndReadBack() async throws {
        let directory = scratchPath()
        defer { remove(directory) }

        let cache = ImageCache(directory: directory)
        let id = UUID()

        #expect(cache.saveToDisk(samplePhoto, for: id) == true)
        #expect(cache.loadDataFromDisk(for: id) == samplePhoto)
    }

    // A missing directory must be recreated on save, not break every later save.
    @Test("пропавшая папка воссоздаётся, а не ломает сохранение навсегда")
    func testSaveRecreatesAMissingDirectory() async throws {
        let directory = scratchPath()
        defer { remove(directory) }

        let cache = ImageCache(directory: directory)

        #expect(cache.saveToDisk(samplePhoto, for: UUID()) == true)
        remove(directory)
        #expect(FileManager.default.fileExists(atPath: directory.path) == false)

        #expect(cache.saveToDisk(samplePhoto, for: UUID()) == true)
        #expect(FileManager.default.fileExists(atPath: directory.path) == true)
    }

    // A plain file where the directory belongs fails both the write and the recreate.
    @Test("неустранимая ошибка записи возвращает false, а не молчит")
    func testSaveReportsAnUnrecoverableFailure() async throws {
        // A file path, not a directory one: Data.write refuses a URL ending in a separator.
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PlekioImageCacheTests-\(UUID().uuidString)", isDirectory: false)
        defer { remove(directory) }

        try Data("in the way".utf8).write(to: directory)

        let cache = ImageCache(directory: directory)

        #expect(cache.saveToDisk(samplePhoto, for: UUID()) == false)
    }

    @Test("удаление убирает файл с диска")
    func testDeleteRemovesTheFile() async throws {
        let directory = scratchPath()
        defer { remove(directory) }

        let cache = ImageCache(directory: directory)
        let id = UUID()

        #expect(cache.saveToDisk(samplePhoto, for: id) == true)
        cache.deleteFromDisk(for: id)

        #expect(cache.loadDataFromDisk(for: id) == nil)
    }

    // MARK: - Size on disk

    /// A JPEG of the given pixel size. Scale is pinned to 1 so points equal pixels on any device.
    private func photo(longEdge: Int) -> Data {
        let size = CGSize(width: longEdge, height: longEdge * 3 / 4)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.jpegData(compressionQuality: 1)!
    }

    private func storedSize(of data: Data, in cache: ImageCache) -> CGSize? {
        let id = UUID()
        guard cache.saveToDisk(data, for: id),
              let stored = cache.loadDataFromDisk(for: id),
              let image = UIImage(data: stored)
        else { return nil }
        return image.size
    }

    // A camera frame is 4032px and up; nothing in the app draws above 1400.
    @Test("большое фото ужимается при сохранении")
    func testOversizedPhotoIsDownscaledOnSave() async throws {
        let directory = scratchPath()
        defer { remove(directory) }

        let original = photo(longEdge: 4032)
        let size = try #require(storedSize(of: original, in: ImageCache(directory: directory)))

        #expect(max(size.width, size.height) <= 2048)
    }

    @Test("фото в пределах лимита сохраняется как есть")
    func testPhotoWithinTheCapIsStoredUnchanged() async throws {
        let directory = scratchPath()
        defer { remove(directory) }

        let cache = ImageCache(directory: directory)
        let original = photo(longEdge: 1200)
        let id = UUID()

        #expect(cache.saveToDisk(original, for: id))
        // Byte-for-byte: re-encoding an already small photo would only lose quality.
        #expect(cache.loadDataFromDisk(for: id) == original)
    }

    @Test("размер на диске — сумма сохранённых файлов")
    func testDiskUsageSumsStoredFiles() async throws {
        let directory = scratchPath()
        defer { remove(directory) }

        let cache = ImageCache(directory: directory)
        #expect(cache.diskUsageBytes() == 0)

        let one = photo(longEdge: 800)
        #expect(cache.saveToDisk(one, for: UUID()))
        #expect(cache.saveToDisk(one, for: UUID()))

        #expect(cache.diskUsageBytes() == Int64(one.count) * 2)
    }
}
