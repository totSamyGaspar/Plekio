//
//  ImageLoading.swift
//  Plekio
//
//  Created by Edward Gasparian on 25.09.2026.
//

import SwiftUI

// MARK: - ImageLoading

nonisolated protocol ImageLoading: Sendable {
    /// `targetPointSize` nil means full size.
    func image(for id: UUID, targetPointSize: CGFloat?) async -> UIImage?
}

extension ImageCache: ImageLoading {}

// MARK: - Environment

private nonisolated struct ImageLoaderKey: EnvironmentKey {
    /// The shared cache, so previews outside the app root still find photos.
    static let defaultValue: any ImageLoading = ImageCache.shared
}

extension EnvironmentValues {
    nonisolated var imageLoader: any ImageLoading {
        get { self[ImageLoaderKey.self] }
        set { self[ImageLoaderKey.self] = newValue }
    }
}

private nonisolated struct DatabaseChangesKey: EnvironmentKey {
    /// A feed nobody writes to; the root injects the store's real feed.
    static let defaultValue = DatabaseChangeFeed()
}

extension EnvironmentValues {
    /// The store's writes, for views that react to them without a view model.
    nonisolated var databaseChanges: DatabaseChangeFeed {
        get { self[DatabaseChangesKey.self] }
        set { self[DatabaseChangesKey.self] = newValue }
    }
}
