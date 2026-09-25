//
//  DatabaseChange.swift
//  Plekio
//
//  Created by Edward Gasparian on 03.09.2026.
//

import Combine
import Foundation

// MARK: - DatabaseChange

/// Areas a write can touch; subscribers are notified only for areas they care about.
nonisolated enum DatabaseChange: String, Hashable, Sendable {

    /// Courses and medications, including stock, schedules and photos.
    case courses

    /// A dose logged or un-logged; separate because it is frequent and rarely of interest.
    case doses

    /// Diary entries, their photos, and blood-pressure readings.
    case diary
}

// MARK: - DatabaseChangeFeed

/// The stream of one store's writes. `@unchecked Sendable` is safe: the only
/// state is a PassthroughSubject, which may be sent to from any thread.
nonisolated final class DatabaseChangeFeed: @unchecked Sendable {

    // MARK: - Properties

    private let subject = PassthroughSubject<Set<DatabaseChange>, Never>()

    // MARK: - Init

    init() {}

    // MARK: - Public

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

// MARK: - DatabaseChangeSource

/// Anything that announces its writes: the real store and the test mock.
protocol DatabaseChangeSource {
    var changes: DatabaseChangeFeed { get }
}
