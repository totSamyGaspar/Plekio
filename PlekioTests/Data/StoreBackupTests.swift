//
//  StoreBackupTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 30.09.2026.
//

import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("Store backup before migration")
struct StoreBackupTests {

    // MARK: - Helpers

    private let fileManager = FileManager.default

    /// A location with a fake store (all three SQLite files) last opened with `version`.
    private func location(storeOpenedWith version: String?) throws -> StorageLocation {
        let location = StorageLocation(root: fileManager.temporaryDirectory
            .appending(path: "StoreBackupTests-\(UUID().uuidString)", directoryHint: .isDirectory))
        for file in location.storeFiles {
            try Data(file.lastPathComponent.utf8).write(to: file)
        }
        if let version {
            try version.write(to: location.storeVersionURL, atomically: true, encoding: .utf8)
        }
        return location
    }

    private func copies(in location: StorageLocation) -> [String] {
        ((try? fileManager.contentsOfDirectory(atPath: location.backupsDirectory.path)) ?? []).sorted()
    }

    // MARK: - Tests

    @Test("Same version: nothing is copied")
    func sameVersionIsNotCopied() throws {
        let location = try location(storeOpenedWith: "1.0.0")
        defer { try? fileManager.removeItem(at: location.root) }

        try StoreBackup(location: location).backUpIfMigrating(to: "1.0.0")

        #expect(copies(in: location).isEmpty)
    }

    @Test("New version: all store files are copied into one folder")
    func newVersionCopiesEveryFile() throws {
        let location = try location(storeOpenedWith: "1.0.0")
        defer { try? fileManager.removeItem(at: location.root) }

        try StoreBackup(location: location).backUpIfMigrating(to: "2.0.0", now: Date(timeIntervalSince1970: 1_000))

        #expect(copies(in: location) == ["1000-1.0.0"])
        let folder = location.backupsDirectory.appending(path: "1000-1.0.0")
        for file in location.storeFiles {
            let copy = try Data(contentsOf: folder.appending(path: file.lastPathComponent))
            #expect(copy == Data(file.lastPathComponent.utf8))
        }
    }

    @Test("No store yet (first launch): nothing is copied")
    func freshInstallIsNotCopied() throws {
        let location = try location(storeOpenedWith: nil)
        defer { try? fileManager.removeItem(at: location.root) }
        for file in location.storeFiles { try fileManager.removeItem(at: file) }

        try StoreBackup(location: location).backUpIfMigrating(to: "1.0.0")

        #expect(copies(in: location).isEmpty)
    }

    @Test("Only the newest copies are kept")
    func oldCopiesArePruned() throws {
        let location = try location(storeOpenedWith: nil)
        defer { try? fileManager.removeItem(at: location.root) }
        let backup = StoreBackup(location: location)

        for second in 1...(StoreBackup.keptCopies + 2) {
            try backup.backUpIfMigrating(to: "1.0.0", now: Date(timeIntervalSince1970: TimeInterval(1_000 + second)))
        }

        #expect(copies(in: location) == ["1003-unknown", "1004-unknown", "1005-unknown"])
    }

    @Test("A failed copy throws and leaves no partial folder")
    func failedCopyThrows() throws {
        let location = try location(storeOpenedWith: "1.0.0")
        defer { try? fileManager.removeItem(at: location.root) }
        // A file where the folder should be, so the copy can't be made.
        try Data().write(to: location.backupsDirectory)

        #expect(throws: (any Error).self) {
            try StoreBackup(location: location).backUpIfMigrating(to: "2.0.0")
        }
    }

    @Test("Without a backup the store is not opened, and it stays as it was")
    func failedBackupStopsTheOpen() throws {
        let location = try location(storeOpenedWith: "0.9.0")
        defer { try? fileManager.removeItem(at: location.root) }
        try Data().write(to: location.backupsDirectory)
        let store = try Data(contentsOf: location.storeURL)

        let persistence = PersistenceController(location: location, photos: FakePhotoStore(), errors: SpyErrorReporter())

        #expect(persistence.storageFailure != nil)
        #expect(try Data(contentsOf: location.storeURL) == store)
        #expect(try String(contentsOf: location.storeVersionURL, encoding: .utf8) == "0.9.0")
    }
}
