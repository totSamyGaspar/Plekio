//
//  DatabaseChange.swift
//  Plekio
//
//  What a storage write touched, and the channel it is announced on.
//
//  Named areas rather than one "something changed" signal, which every screen has
//  to treat as "everything changed": saving a diary entry would make the
//  dashboard, the course list and the statistics re-fetch
//  and recompute from scratch. The first patch for that was a second name,
//  `.diaryDidUpdate`, posted alongside the broad one — which fixed the diary and
//  left the asymmetry in place. A name per area does not scale; a payload does.
//
//  The channel used to be `NotificationCenter.default`: a string name, the set
//  carried in `userInfo` under another string, and a cast on the receiving end.
//  It was also global — one database's writes woke every subscriber in the
//  process, so tests running side by side refreshed each other's view models.
//  Now each store owns a DatabaseChangeFeed and whoever listens is handed that
//  feed: the type says what travels on it, and two stores cannot hear each other.
//

import Combine
import Foundation

/// The areas a write can touch. A write declares what it changed, a subscriber
/// declares what concerns it, and the two are matched — instead of every screen
/// reacting to every write in the app.
nonisolated enum DatabaseChange: String, Hashable, Sendable {

    /// Courses and medications: names, dates, schedule times, stock, photos,
    /// additions and deletions.
    case courses

    /// A dose logged or un-logged. Separate from `courses` because it happens
    /// far more often than anything else — every tap on the dashboard — and most
    /// of what listens does not care.
    case doses

    /// Diary entries, their photos, and blood pressure readings. One area: they
    /// are written from the same screens and read by the same one.
    case diary
}

/// The stream of one store's writes.
///
/// Nonisolated and `@unchecked Sendable` so it can sit in the SwiftUI
/// environment and in default arguments; the only state is a
/// PassthroughSubject, which Combine documents as safe to send to from any
/// thread. In practice every write commits on the main actor.
nonisolated final class DatabaseChangeFeed: @unchecked Sendable {

    private let subject = PassthroughSubject<Set<DatabaseChange>, Never>()

    init() {}

    /// Called by PersistenceController after a successful commit, and by tests.
    func send(_ changes: Set<DatabaseChange>) {
        subject.send(changes)
    }

    /// Fires when a write touched any of `interests`, and stays silent otherwise.
    func publisher(for interests: Set<DatabaseChange>) -> AnyPublisher<Void, Never> {
        subject
            .filter { !$0.isDisjoint(with: interests) }
            .map { _ in () }
            .eraseToAnyPublisher()
    }
}

/// Anything that announces its writes: the real store and the test mock.
protocol DatabaseChangeSource {
    var changes: DatabaseChangeFeed { get }
}
