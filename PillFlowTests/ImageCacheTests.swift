//
//  ImageCacheTests.swift
//  PillFlowTests
//
//  Tests for the disk half of ImageCache. The flag saveToDisk returns was
//  discarded at every call site, so a medication or diary entry could be listed
//  as saved while its photo had never reached the disk. These pin down the two
//  halves of the fix: the write reports honestly whether it worked, and a
//  missing photo directory is recreated rather than failing every save from
//  then on.
//
//  Each test gets its own temporary directory through ImageCache(directory:),
//  so none of them touch the app's real photo store or each other.
//

import Testing
import Foundation
@testable import PillFlow

@MainActor
@Suite("ImageCache disk storage")
struct ImageCacheTests {

    /// A path inside the temp folder that does not exist yet. The caller decides
    /// what to put there — a real directory, or a file in the way.
    private func scratchPath() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("PillFlowImageCacheTests-\(UUID().uuidString)", isDirectory: true)
    }

    private func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private var samplePhoto: Data { Data("not really a jpeg, but bytes are bytes".utf8) }

    @Test("сохранение в существующую папку удаётся, и байты читаются обратно")
    func testSaveAndReadBack() async throws {
        let directory = scratchPath()
        defer { remove(directory) }

        let cache = ImageCache(directory: directory)
        let id = UUID()

        #expect(cache.saveToDisk(samplePhoto, for: id) == true)
        #expect(cache.loadDataFromDisk(for: id) == samplePhoto)
    }

    // The directory is created once at startup with the result discarded. If that
    // ever failed, every save afterwards failed too — silently, and permanently,
    // because nothing ever tried to create it again.
    @Test("пропавшая папка воссоздаётся, а не ломает сохранение навсегда")
    func testSaveRecreatesAMissingDirectory() async throws {
        let directory = scratchPath()
        defer { remove(directory) }

        let cache = ImageCache(directory: directory)

        // The folder disappears underneath the app between one save and the next.
        #expect(cache.saveToDisk(samplePhoto, for: UUID()) == true)
        remove(directory)
        #expect(FileManager.default.fileExists(atPath: directory.path) == false)

        #expect(cache.saveToDisk(samplePhoto, for: UUID()) == true)
        #expect(FileManager.default.fileExists(atPath: directory.path) == true)
    }

    // The other half: when the write cannot be rescued, saveToDisk has to say so
    // rather than return true and lose the photo quietly. A plain file sitting
    // where the directory belongs fails both the write and the recreate.
    @Test("неустранимая ошибка записи возвращает false, а не молчит")
    func testSaveReportsAnUnrecoverableFailure() async throws {
        // Built as a FILE path, not a directory one: Data.write refuses a URL
        // that ends in a separator.
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PillFlowImageCacheTests-\(UUID().uuidString)", isDirectory: false)
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
}
