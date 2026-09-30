//
//  StorageLocation.swift
//  Plekio
//
//  Created by Edward Gasparian on 29.09.2026.
//

import Foundation

/// The one place that knows where the app's files live. They sit in the App Group
/// container, so a widget or watch app can later read the same store.
nonisolated struct StorageLocation: Sendable {

    static let appGroupId = "group.com.EdHasp.Plekio"

    /// The app's location, built once by `AppDependencies.live()`. A missing App Group
    /// is a signing error, not a runtime condition: storing data elsewhere would hide it
    /// until the files are lost.
    static func appGroup() -> StorageLocation {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            fatalError("App Group \(appGroupId) is missing from the entitlements")
        }
        return StorageLocation(root: container.appending(path: "Library/Application Support", directoryHint: .isDirectory))
    }

    /// Created on init: SwiftData does not create the store's folder.
    let root: URL

    init(root: URL) {
        self.root = root
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    var storeURL: URL { root.appending(path: "Plekio.store") }

    var storeFiles: [URL] { Self.files(ofStore: storeURL) }

    /// A store is several files: SQLite keeps recent writes in -wal until a checkpoint,
    /// and -wal can outweigh the store itself.
    static func files(ofStore url: URL) -> [URL] {
        ["", "-wal", "-shm"].map { URL(filePath: url.path + $0) }
    }

    /// The schema version the store was last opened with, as plain text.
    var storeVersionURL: URL { root.appending(path: "store-version") }

    /// Copies of the store taken before a migration, one folder each.
    var backupsDirectory: URL { root.appending(path: "Backups", directoryHint: .isDirectory) }

    /// Photos live beside the store, not in it, so fetches never load image data.
    var photosDirectory: URL { root.appending(path: "MedicationImages", directoryHint: .isDirectory) }
}
