//
//  StorageUsage.swift
//  Plekio
//
//  Created by Edward Gasparian on 19.09.2026.
//

import Foundation

/// Disk usage, split into photos and database since they grow at very different rates.
nonisolated struct StorageUsage: Equatable {

    // MARK: - Properties

    let photoBytes: Int64
    let databaseBytes: Int64

    var totalBytes: Int64 { photoBytes + databaseBytes }

    // MARK: - Measuring

    /// Reads the filesystem. Call off the main actor.
    static func measure(storeURL: URL?, photoCache: ImageCache) -> StorageUsage {
        StorageUsage(
            photoBytes: photoCache.diskUsageBytes(),
            databaseBytes: storeURL.map(storeBytes(at:)) ?? 0
        )
    }

    private static func storeBytes(at url: URL) -> Int64 {
        StorageLocation.files(ofStore: url).reduce(0) { $0 + ImageCache.fileSize(at: $1) }
    }
}
