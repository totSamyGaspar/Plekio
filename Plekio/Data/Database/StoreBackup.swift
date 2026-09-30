//
//  StoreBackup.swift
//  Plekio
//
//  Created by Edward Gasparian on 30.09.2026.
//

import Foundation
import OSLog

/// Copies the store before it is opened with a new schema version, so a failed
/// migration can be undone. Runs before the container exists: nothing has the
/// files open, so the copy is consistent.
nonisolated struct StoreBackup {

    /// Newer copies are kept; older ones are deleted after each backup.
    static let keptCopies = 3

    let location: StorageLocation
    private let fileManager = FileManager.default

    init(location: StorageLocation) {
        self.location = location
    }

    // MARK: - Before Opening

    /// Copies the store when it was last opened with a different schema version
    /// (or with none recorded). Throws when a needed copy fails: the store must
    /// not be migrated then.
    func backUpIfMigrating(to version: String, now: Date = .now) throws {
        guard fileManager.fileExists(atPath: location.storeURL.path) else { return }
        let lastOpened = try? String(contentsOf: location.storeVersionURL, encoding: .utf8)
        guard lastOpened != version else { return }

        // Timestamp first, so folder names sort oldest to newest.
        let name = "\(Int(now.timeIntervalSince1970))-\(lastOpened ?? "unknown")"
        let folder = location.backupsDirectory.appending(path: name, directoryHint: .isDirectory)
        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            for file in location.storeFiles where fileManager.fileExists(atPath: file.path) {
                try fileManager.copyItem(at: file, to: folder.appending(path: file.lastPathComponent))
            }
        } catch {
            // A partial copy can't restore anything.
            try? fileManager.removeItem(at: folder)
            AppLog.storage.critical("Store backup failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }

        AppLog.storage.notice("Store backed up before migration from \(lastOpened ?? "unknown", privacy: .public)")
        removeOldCopies()
    }

    // MARK: - After Opening

    /// Records the version the store now has. Called only after a successful open.
    func recordOpened(with version: String) {
        do {
            try version.write(to: location.storeVersionURL, atomically: true, encoding: .utf8)
        } catch {
            // Only costs an extra backup on the next launch.
            AppLog.storage.error("Store version not recorded: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Pruning

    private func removeOldCopies() {
        let copies = (try? fileManager.contentsOfDirectory(atPath: location.backupsDirectory.path)) ?? []
        for name in copies.sorted().dropLast(Self.keptCopies) {
            try? fileManager.removeItem(at: location.backupsDirectory.appending(path: name))
        }
    }
}
