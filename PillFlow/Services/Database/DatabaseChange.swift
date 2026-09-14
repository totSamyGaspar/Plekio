//
//  DatabaseChange.swift
//  PillFlow
//
//  What a storage write touched, and the one channel it is announced on.
//
//  Named areas rather than one "something changed" signal, which every screen has
//  to treat as "everything changed": saving a diary entry would make the
//  dashboard, the course list and the statistics re-fetch
//  and recompute from scratch. The first patch for that was a second name,
//  `.diaryDidUpdate`, posted alongside the broad one — which fixed the diary and
//  left the asymmetry in place. A name per area does not scale; a payload does.
//

import Combine
import Foundation

/// The areas a write can touch. A write declares what it changed, a subscriber
/// declares what concerns it, and the two are matched — instead of every screen
/// reacting to every write in the app.
enum DatabaseChange: String, Hashable, Sendable {

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

    /// Key the change set travels under in `Notification.userInfo`.
    static let userInfoKey = "databaseChanges"
}

extension Notification.Name {

    /// One channel for every storage write. What changed rides in the payload,
    /// not in the name.
    static let databaseDidChange = Notification.Name("databaseDidChange")
}

extension Notification {

    /// Whether this notification announces a change to any of `interests`.
    ///
    /// A notification with no payload counts as touching everything: better a
    /// needless refresh than a screen left showing stale data, should something
    /// ever post the name by hand.
    ///
    /// Named rather than inlined into the publisher below so the rule can be
    /// tested without going through the global notification centre — which is
    /// shared by the whole test process and would make such a test depend on
    /// what else happens to be running.
    func touchesDatabase(_ interests: Set<DatabaseChange>) -> Bool {
        guard let posted = userInfo?[DatabaseChange.userInfoKey] as? Set<DatabaseChange> else {
            return true
        }
        return !posted.isDisjoint(with: interests)
    }
}

extension NotificationCenter {

    /// Fires when a write touched any of `changes`, and stays silent otherwise.
    func publisher(forDatabaseChanges changes: Set<DatabaseChange>) -> AnyPublisher<Void, Never> {
        publisher(for: .databaseDidChange)
            .filter { $0.touchesDatabase(changes) }
            .map { _ in () }
            .eraseToAnyPublisher()
    }
}
