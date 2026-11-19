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
    /// A local wall-clock time, `yyyy-MM-dd'T'HH:mm`, the app's clock starts at.
    static let nowFlag = "-ui-now"

    // MARK: - Seed

    /// The state the app starts in. Each launch starts from scratch, so a test
    /// never depends on what an earlier test left behind.
    enum Seed: String, CaseIterable, Sendable {
        /// Onboarding and the tour done, no courses: the app as after first setup.
        case empty
        /// A fresh install: onboarding still to come.
        case onboarding
        /// One running course with a dose at 09:00 and one due at launch,
        /// so Today always has an Up next card.
        case today
    }

    let seed: Seed
    /// Where the clock starts; nil keeps the real time.
    let now: Date?

    // MARK: - Init

    init(seed: Seed, now: Date? = nil) {
        self.seed = seed
        self.now = now
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
        now = Self.value(after: Self.nowFlag, in: arguments).flatMap(Self.parseLocalTime)
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    /// Read as wall-clock time in the device's own zone, not as an instant:
    /// "08:30" is 08:30 on the screen whether the simulator runs in UTC (Xcode
    /// Cloud) or in Tbilisi, so the same test sees the same day everywhere.
    static func parseLocalTime(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter.date(from: text)
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
