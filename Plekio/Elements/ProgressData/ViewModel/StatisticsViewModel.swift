//
//  StatisticsViewModel.swift
//  Plekio
//
//  Created by Edward Gasparian on 06.05.2026.
//

import SwiftUI
import Combine


@MainActor
final class StatisticsViewModel: StatisticsViewModelProtocol {
    @Published var takenCount: Int = 0
    @Published var totalCount: Int = 0
    @Published var streakDays: Int = 0
    @Published var lowStockItems: [MedicationSnapshot] = []

    /// Snapshots of the courses — for the low-stock list and the refill.
    private let courses: any CourseRepository
    /// The dose schedule — for adherence and the streak.
    private let doses: any DoseStoring
    private let errors: any ErrorReporting
    private let time: any TimeSource
    private var cancellables = Set<AnyCancellable>()

    private static let streakLookbackDays = 30
    /// Fraction of a day's doses that has to be logged for the day to count.
    private static let streakThreshold = 0.9

    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(takenCount) / Double(totalCount)
    }

    init(courses: any CourseRepository, doses: any DoseStoring, errors: any ErrorReporting, changes: DatabaseChangeFeed, time: any TimeSource = SystemTime()) {
        self.time = time
        self.courses = courses
        self.doses = doses
        self.errors = errors
        loadStats()

        // Adherence is computed from the schedule and the logs, so both matter.
        changes.publisher(for: [.courses, .doses])
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.loadStats() }
            .store(in: &cancellables)
    }

    /// Over the SwiftData store — the shape tests use.
    convenience init(dbService: any CourseStoring & DoseStoring & DatabaseChangeSource, errors: any ErrorReporting) {
        self.init(courses: SwiftDataCourseRepository(store: dbService), doses: dbService, errors: errors, changes: dbService.changes)
    }

    func loadStats() {
        let calendar = Calendar.current
        let now = time.now
        let today = calendar.startOfDay(for: now)

        // Today and the lookback window in one read.
        let days = (0...Self.streakLookbackDays).compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today)
        }
        let pillsByDay = doses.fetchPills(onDays: days)

        let todaysPills = pillsByDay[today] ?? []
        self.totalCount = todaysPills.count
        self.takenCount = todaysPills.filter { $0.isTaken }.count

        // Unfinished courses only: there is no point reminding the user to restock
        // a medication for a course that has already ended.
        self.lowStockItems = courses.allCourses()
            .filter { $0.isActive(on: now, calendar: calendar) }
            .flatMap(\.medications)
            .filter(\.isLowOnStock)

        self.streakDays = Self.streak(pillsByDay: pillsByDay, today: today, calendar: calendar)
    }

    // MARK: - Streak

    /// How many consecutive days adherence stayed at or above `streakThreshold`.
    ///
    /// Today counts once it is already fully logged, but it never breaks the
    /// streak: the day is not over, and recording it as a miss at 10am would be
    /// lying to the user.
    ///
    /// The denominator comes from the schedule (`fetchPills`), not from the number
    /// of `DoseLog` records found: a log exists only once a dose has been logged,
    /// so counted from those a "took 1 of 3" day scores
    /// 1/1 = 100%, so the streak grew more reliably the fewer doses a person
    /// logged.
    private static func streak(pillsByDay: [Date: [PillDose]], today: Date, calendar: Calendar) -> Int {
        var streak = 0

        // Today can only add: logged in full, the streak is already 1 without
        // waiting for midnight; not logged, the day is simply skipped.
        if let todayAdherence = adherence(of: pillsByDay[today] ?? []),
           todayAdherence >= streakThreshold {
            streak += 1
        }

        // Backwards from yesterday: those days are closed and can break the streak.
        for offset in 1...streakLookbackDays {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { break }

            // A day with nothing scheduled neither breaks nor extends the streak —
            // there is nothing to measure. Otherwise a once-a-week course could never
            // build one at all.
            guard let dayAdherence = adherence(of: pillsByDay[day] ?? []) else { continue }
            guard dayAdherence >= streakThreshold else { break }

            streak += 1
        }

        return streak
    }

    /// Fraction of the day's doses that were logged; `nil` if nothing was scheduled.
    private static func adherence(of scheduled: [PillDose]) -> Double? {
        guard !scheduled.isEmpty else { return nil }
        let taken = scheduled.filter(\.isTaken).count
        return Double(taken) / Double(scheduled.count)
    }

    // MARK: - Refill

    /// Returns whether the stock was saved, so the screen confirms only what
    /// actually happened — on failure the error alert is the only thing shown.
    @discardableResult
    func refill(medication: MedicationSnapshot, amount: Int) -> Bool {
        guard errors.run({
            try courses.refillStock(medicationId: medication.id, amount: amount)
        }) else { return false }

        loadStats()
        return true
    }
}
