//
//  ImageLoading.swift
//  Plekio
//
//  Decoded photos, sized for where they are shown. What views and the report
//  renderer need — as opposed to PhotoStoring, the raw files the database
//  writes and deletes.
//
//  Views get it from the SwiftUI environment, the way they get `dismiss` or
//  `openURL`: photo views sit deep inside rows, cards and sheets, and threading
//  a loader through every initialiser on the way down would touch dozens of
//  call sites for no gain. The root sets it from the composition root
//  (`.environment(\.imageLoader, dependencies.photoCache)`); a preview or a test
//  can set its own.
//

import SwiftUI

nonisolated protocol ImageLoading: Sendable {
    /// `targetPointSize` nil means full size.
    func image(for id: UUID, targetPointSize: CGFloat?) async -> UIImage?
}

extension ImageCache: ImageLoading {}

private nonisolated struct ImageLoaderKey: EnvironmentKey {
    /// The app's cache, so a view shown outside the app's root — a preview, a
    /// snapshot — still finds photos. The root sets it explicitly regardless.
    static let defaultValue: any ImageLoading = ImageCache.shared
}

extension EnvironmentValues {
    nonisolated var imageLoader: any ImageLoading {
        get { self[ImageLoaderKey.self] }
        set { self[ImageLoaderKey.self] = newValue }
    }
}

private nonisolated struct DatabaseChangesKey: EnvironmentKey {
    /// A feed nobody writes to: a view outside the app's root — a preview —
    /// simply never hears of a change. The root sets the store's own feed.
    static let defaultValue = DatabaseChangeFeed()
}

extension EnvironmentValues {
    /// The store's writes, for views that react to them without a view model.
    nonisolated var databaseChanges: DatabaseChangeFeed {
        get { self[DatabaseChangesKey.self] }
        set { self[DatabaseChangesKey.self] = newValue }
    }
}
