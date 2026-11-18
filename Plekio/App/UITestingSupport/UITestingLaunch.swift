//
//  UITestingLaunch.swift
//  Plekio
//
//  Created by Edward Gasparian on 18.11.2026.
//

#if DEBUG
import Foundation

// MARK: - UITestingLaunch

/// How a UI test asked the app to start: `-ui-testing`, optionally `-ui-seed <name>`.
/// Nil for every normal launch, so nothing below can reach a user's data.
/// DEBUG only: an App Store build ignores the arguments entirely.
nonisolated struct UITestingLaunch: Equatable, Sendable {

    // MARK: - Arguments

    static let flag = "-ui-testing"
    static let seedFlag = "-ui-seed"

    // MARK: - Seed

    /// The state the app starts in. Each launch starts from scratch, so a test
    /// never depends on what an earlier test left behind.
    enum Seed: String, CaseIterable, Sendable {
        /// Onboarding and the tour done, no courses: the app as after first setup.
        case empty
        /// A fresh install: onboarding still to come.
        case onboarding
        /// One running course with a morning and an evening dose today.
        case today
    }

    let seed: Seed

    // MARK: - Init

    init(seed: Seed) {
        self.seed = seed
    }

    /// An unknown or missing seed falls back to `.empty` rather than failing the
    /// launch: the test then fails on what it sees, which says more.
    init?(arguments: [String]) {
        guard arguments.contains(Self.flag) else { return nil }
        if let index = arguments.firstIndex(of: Self.seedFlag),
           arguments.indices.contains(index + 1),
           let seed = Seed(rawValue: arguments[index + 1]) {
            self.seed = seed
        } else {
            self.seed = .empty
        }
    }

    /// Read once per process; launch arguments never change while it runs.
    static let current = UITestingLaunch(arguments: ProcessInfo.processInfo.arguments)

    // MARK: - Storage

    /// Separate from the app's own domain, and wiped on every launch.
    static let defaultsSuite = "PlekioUITesting"

    /// Off the App Group: a UI-testing run must never open, migrate or back up the real store.
    static var location: StorageLocation {
        StorageLocation(root: FileManager.default.temporaryDirectory
            .appending(path: "PlekioUITesting", directoryHint: .isDirectory))
    }
}
#endif
