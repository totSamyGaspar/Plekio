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

        try transferStore(into: location.backupsDirectory, named: folderName(lastOpened, now), moving: false)
        AppLog.storage.notice("Store backed up before migration from \(lastOpened ?? "unknown", privacy: .public)")
        removeOldCopies()
    }

    // MARK: - Start Fresh

    /// Moves the store out of the way, never deleting it, so the next open starts
    /// empty and a later update can still recover the old data.
    func setAsideStore(now: Date = .now) throws {
        let lastOpened = try? String(contentsOf: location.storeVersionURL, encoding: .utf8)
        try transferStore(into: location.recoveredDirectory, named: folderName(lastOpened, now), moving: true)
        try? fileManager.removeItem(at: location.storeVersionURL)
        AppLog.storage.notice("Store set aside to start fresh")
    }

    // MARK: - Files

    /// Timestamp first, so folder names sort oldest to newest.
    private func folderName(_ version: String?, _ now: Date) -> String {
        "\(Int(now.timeIntervalSince1970))-\(version ?? "unknown")"
    }

    /// All or nothing: a partial copy can't restore anything. A failed move puts
    /// back what already moved, so the store is never left half-gone.
    private func transferStore(into parent: URL, named name: String, moving: Bool) throws {
        let folder = parent.appending(path: name, directoryHint: .isDirectory)
        var moved: [(from: URL, to: URL)] = []
        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            for file in location.storeFiles where fileManager.fileExists(atPath: file.path) {
                let target = folder.appending(path: file.lastPathComponent)
                if moving {
                    try fileManager.moveItem(at: file, to: target)
                    moved.append((file, target))
                } else {
                    try fileManager.copyItem(at: file, to: target)
                }
            }
        } catch {
            for file in moved { try? fileManager.moveItem(at: file.to, to: file.from) }
            try? fileManager.removeItem(at: folder)
            AppLog.storage.critical("Store transfer failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
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
