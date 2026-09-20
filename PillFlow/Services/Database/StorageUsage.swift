//
//  StorageUsage.swift
//  PillFlow
//

import Foundation

/// What the app occupies on disk, split into the two things that grow with use.
///
/// They grow at very different rates — a year of dose logs is a couple of
/// megabytes, a single full-size photo is more than that — so one total would
/// hide which of them is worth acting on.
nonisolated struct StorageUsage: Equatable {

    let photoBytes: Int64
    let databaseBytes: Int64

    var totalBytes: Int64 { photoBytes + databaseBytes }

    /// Reads the filesystem. Call off the main actor.
    static func measure(storeURL: URL?) -> StorageUsage {
        StorageUsage(
            photoBytes: ImageCache.shared.diskUsageBytes(),
            databaseBytes: storeURL.map(storeBytes(at:)) ?? 0
        )
    }

    /// SQLite keeps a write-ahead log and a shared-memory file beside the store,
    /// and the log alone can outweigh it. All three count.
    private static func storeBytes(at url: URL) -> Int64 {
        ["", "-wal", "-shm"]
            .map { URL(filePath: url.path + $0) }
            .reduce(0) { $0 + ImageCache.fileSize(at: $1) }
    }
}
