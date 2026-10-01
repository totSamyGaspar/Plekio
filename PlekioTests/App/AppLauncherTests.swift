//
//  AppLauncherTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 30.09.2026.
//

import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("App launch and storage recovery")
struct AppLauncherTests {

    // MARK: - Helpers

    private struct StoreUnavailable: Error {}

    /// A store that opens only once `isAvailable` is set. A main-actor class, so the
    /// launcher's closure can share it and sees later changes.
    @MainActor
    private final class FakeStore {
        var isAvailable = false
    }

    private let location = StorageLocation(root: FileManager.default.temporaryDirectory
        .appending(path: "AppLauncherTests-\(UUID().uuidString)", directoryHint: .isDirectory))

    /// A graph on an in-memory store, standing in for a store that opened.
    private func openedGraph(_: StorageLocation) -> AppDependencies {
        AppDependencies(
            database: DatabaseService(inMemoryForTesting: true),
            notifications: MockNotificationService(),
            photoCache: ImageCache(directory: location.photosDirectory),
            settings: SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!),
            errorPresenter: AppErrorPresenter(),
            tipJar: PreviewTipJar()
        )
    }

    private func makeLauncher(opening store: FakeStore) -> AppLauncher {
        AppLauncher(location: location) { location in
            guard store.isAvailable else { throw StoreUnavailable() }
            return openedGraph(location)
        }
    }

    // MARK: - Tests

    @Test("A store that can't be opened leaves the app without a graph")
    func failedOpenHasNoGraph() {
        let launcher = makeLauncher(opening: FakeStore())

        #expect(launcher.dependencies == nil)
        #expect(launcher.failureDetails != nil)
    }

    @Test("Retrying after the cause has cleared opens the app")
    func retryOpensOnceTheCauseClears() {
        let store = FakeStore()
        let launcher = makeLauncher(opening: store)

        store.isAvailable = true
        launcher.retry()

        #expect(launcher.dependencies != nil)
        #expect(launcher.failureDetails == nil)
    }

    @Test("Starting fresh sets the old store aside and opens a new one")
    func startFreshKeepsTheOldStore() throws {
        defer { try? FileManager.default.removeItem(at: location.root) }
        try Data("old".utf8).write(to: location.storeURL)
        let store = FakeStore()
        let launcher = makeLauncher(opening: store)

        store.isAvailable = true
        launcher.startFresh()

        #expect(launcher.dependencies != nil)
        #expect(!FileManager.default.fileExists(atPath: location.storeURL.path))
        let setAside = try FileManager.default.contentsOfDirectory(atPath: location.recoveredDirectory.path)
        #expect(setAside.count == 1)
    }
}
