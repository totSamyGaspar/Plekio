//
//  WidgetSnapshotStore.swift
//  Plekio
//
//  Created by Edward Gasparian on 21.10.2026.
//

import Foundation
import OSLog

// MARK: - WidgetSnapshotStore

/// Reads and writes the snapshot file. The app writes, the widget only reads.
nonisolated struct WidgetSnapshotStore: Sendable {

    let url: URL

    init(url: URL) {
        self.url = url
    }

    init(location: StorageLocation) {
        self.init(url: location.widgetSnapshotURL)
    }

    /// Not AppLog, which the widget doesn't build; same subsystem scheme, so Console groups them.
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Plekio", category: "widget")

    // MARK: - Reading

    /// Nil when there is no file yet, it can't be decoded, or a newer app wrote a
    /// version this build doesn't know. The widget then shows its placeholder.
    func read() -> WidgetSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            let snapshot = try JSONDecoder().decode(WidgetSnapshot.self, from: data)
            guard snapshot.version == WidgetSnapshot.currentVersion else { return nil }
            return snapshot
        } catch {
            Self.log.error("Snapshot unreadable: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Writing

    /// Atomic: the widget may read while the app writes, and must never see half a file.
    func write(_ snapshot: WidgetSnapshot) throws {
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: url, options: [.atomic])
    }

    /// After "Erase all data": the widget must not keep showing medication names.
    func clear() throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }
}
