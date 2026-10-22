//
//  WidgetSnapshotPublisher.swift
//  Plekio
//
//  Created by Edward Gasparian on 21.10.2026.
//

import Combine
import Foundation
import os

// MARK: - WidgetSnapshotPublisher

/// Keeps the widget's snapshot in step with the store: rebuilt after course and
/// dose writes, on activation, and after a notification action. Every way a dose
/// gets logged ends in a store write, so the widget follows all of them.
@MainActor
final class WidgetSnapshotPublisher {

    // MARK: - Properties

    private let doses: any DoseStoring
    private let courses: any CourseRepository
    /// Nil in tests that only care about doses.
    private let diary: (any DiaryRepository)?
    /// Nil in previews and most tests: nothing is written and no widget is reloaded.
    private let store: WidgetSnapshotStore?
    private let reloader: any WidgetReloading
    private let time: any TimeSource
    private var cancellables = Set<AnyCancellable>()

    /// The last snapshot on disk, so an unchanged one is neither rewritten nor reloaded.
    private var lastWritten: WidgetSnapshot?

    /// The last refresh started, for awaiting it (notification actions, tests).
    private(set) var lastRefresh: Task<Void, Never>?

    // MARK: - Init

    /// `changes` fires once per burst of writes the snapshot has to follow.
    init(
        doses: any DoseStoring,
        courses: any CourseRepository,
        diary: (any DiaryRepository)? = nil,
        store: WidgetSnapshotStore?,
        reloader: any WidgetReloading,
        changes: AnyPublisher<Void, Never>,
        time: any TimeSource
    ) {
        self.doses = doses
        self.courses = courses
        self.diary = diary
        self.store = store
        self.reloader = reloader
        self.time = time

        changes
            .sink { [weak self] in self?.refresh() }
            .store(in: &cancellables)
    }

    /// Follows course, dose and diary writes, debounced so "Log all" costs one rebuild.
    convenience init(
        database: any DoseStoring & DatabaseChangeSource,
        courses: any CourseRepository,
        diary: (any DiaryRepository)? = nil,
        store: WidgetSnapshotStore?,
        reloader: any WidgetReloading = WidgetCenterReloader(),
        time: any TimeSource
    ) {
        self.init(
            doses: database,
            courses: courses,
            diary: diary,
            store: store,
            reloader: reloader,
            // .diary too: the diary and blood-pressure widgets read the same snapshot.
            changes: database.changes
                .publisher(for: [.courses, .doses, .diary])
                .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
                .eraseToAnyPublisher(),
            time: time
        )
    }

    // MARK: - Refresh

    /// Rebuilds the snapshot; the streak's history is read off the main actor.
    ///
    /// Refreshes queue up behind each other and are never cancelled: a caller that
    /// awaits one (a widget button, a notification action) must find the snapshot
    /// written when it returns. A write's own debounced refresh would otherwise
    /// cancel the awaited one, and the widget would redraw the old state.
    @discardableResult
    func refresh() -> Task<Void, Never> {
        guard store != nil else { return Task {} }

        let calendar = time.calendar
        let today = calendar.startOfDay(for: time.now)
        let days = StreakRules.days(endingAt: today, calendar: calendar)

        let previous = lastRefresh
        let task = Task { [weak self, doses] in
            await previous?.value
            let history = await doses.pillHistory(onDays: days)
            guard let self else { return }
            self.publish(streakDays: StreakRules.streak(pillsByDay: history, today: today, calendar: calendar))
        }
        lastRefresh = task
        return task
    }

    // MARK: - Publishing

    /// Today and tomorrow are read here, after the history, so they are as fresh
    /// as possible; a write that landed meanwhile triggers another refresh anyway.
    private func publish(streakDays: Int) {
        guard let store else { return }

        let now = time.now
        let calendar = time.calendar
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today

        let pills = doses.fetchPills(onDays: [today, tomorrow]).values.flatMap { $0 }
        // As on Today's refill card: no restock warning for a course that has ended.
        let lowStock = courses.allCourses()
            .filter { $0.isActive(on: now, calendar: calendar) }
            .flatMap(\.medications)
            .filter(\.isLowOnStock)

        let diaryToday = diary?.allEntries().first { calendar.isDate($0.checkInDate, inSameDayAs: now) }
        let snapshot = WidgetSnapshotBuilder.build(
            pills: pills,
            streakDays: streakDays,
            lowStock: lowStock,
            diaryToday: diaryToday,
            readings: diary?.allBloodPressureReadings() ?? [],
            now: now
        )
        if let lastWritten, Self.sameContent(lastWritten, snapshot) { return }

        do {
            try store.write(snapshot)
            lastWritten = snapshot
            reloader.reloadAll()
        } catch {
            // Not shown to the user: the app works without the widget, which keeps
            // its last snapshot until the next write succeeds.
            AppLog.storage.error("Widget snapshot not written: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Equal apart from when they were built.
    private static func sameContent(_ lhs: WidgetSnapshot, _ rhs: WidgetSnapshot) -> Bool {
        var lhs = lhs
        lhs.generatedAt = rhs.generatedAt
        return lhs == rhs
    }
}
