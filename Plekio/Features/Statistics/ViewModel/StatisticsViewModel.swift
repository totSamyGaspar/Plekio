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

    // MARK: - Properties

    @Published var takenCount: Int = 0
    @Published var totalCount: Int = 0
    @Published var streakDays: Int = 0
    @Published var lowStockItems: [MedicationSnapshot] = []

    private let courses: any CourseRepository
    private let doses: any DoseStoring
    private let errors: any ErrorReporting
    private let time: any TimeSource
    private var cancellables = Set<AnyCancellable>()

    private static let streakLookbackDays = 30
    /// Fraction of a day's doses that must be logged for the day to count toward the streak.
    private static let streakThreshold = 0.9

    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(takenCount) / Double(totalCount)
    }

    // MARK: - Init

    init(courses: any CourseRepository, doses: any DoseStoring, errors: any ErrorReporting, changes: DatabaseChangeFeed, time: any TimeSource = SystemTime()) {
        self.time = time
        self.courses = courses
        self.doses = doses
        self.errors = errors
        loadStats()

        changes.publisher(for: [.courses, .doses])
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.loadStats() }
            .store(in: &cancellables)
    }

    convenience init(dbService: any CourseStoring & DoseStoring & DatabaseChangeSource, errors: any ErrorReporting) {
        self.init(courses: SwiftDataCourseRepository(store: dbService), doses: dbService, errors: errors, changes: dbService.changes)
    }

    // MARK: - Loading

    func loadStats() {
        let calendar = time.calendar
        let now = time.now
        let today = calendar.startOfDay(for: now)

        let days = (0...Self.streakLookbackDays).compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today)
        }
        let pillsByDay = doses.fetchPills(onDays: days)

        let todaysPills = pillsByDay[today] ?? []
        self.totalCount = todaysPills.count
        self.takenCount = todaysPills.filter { $0.isTaken }.count

        // Active courses only: no restock warning for a course that has ended.
        self.lowStockItems = courses.allCourses()
            .filter { $0.isActive(on: now, calendar: calendar) }
            .flatMap(\.medications)
            .filter(\.isLowOnStock)

        self.streakDays = Self.streak(pillsByDay: pillsByDay, today: today, calendar: calendar)
    }

    // MARK: - Streak

    /// Consecutive days at or above `streakThreshold`. Today can add but never break it.
    /// The denominator is the schedule (`fetchPills`), not the logged `DoseLog` records.
    private static func streak(pillsByDay: [Date: [PillDose]], today: Date, calendar: Calendar) -> Int {
        var streak = 0

        if let todayAdherence = adherence(of: pillsByDay[today] ?? []),
           todayAdherence >= streakThreshold {
            streak += 1
        }

        // Past days are closed and can break the streak.
        for offset in 1...streakLookbackDays {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { break }

            // Days with nothing scheduled neither break nor extend the streak.
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

    /// Whether the stock was saved; on failure the error alert has already been shown.
    @discardableResult
    func refill(medication: MedicationSnapshot, amount: Int) -> Bool {
        guard errors.run({
            try courses.refillStock(medicationId: medication.id, amount: amount)
        }) else { return false }

        loadStats()
        return true
    }
}
