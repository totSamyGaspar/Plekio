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

    /// The in-flight history read. Exposed so tests can await it.
    private(set) var historyLoad: Task<Void, Never>?

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

    /// Low stock is read at once; the 30-day history off the main actor.
    func loadStats() {
        let calendar = time.calendar
        let now = time.now
        let today = calendar.startOfDay(for: now)

        // Active courses only: no restock warning for a course that has ended.
        self.lowStockItems = courses.allCourses()
            .filter { $0.isActive(on: now, calendar: calendar) }
            .flatMap(\.medications)
            .filter(\.isLowOnStock)

        let days = StreakRules.days(endingAt: today, calendar: calendar)

        // A newer load supersedes this one; its result must not land on top.
        historyLoad?.cancel()
        historyLoad = Task { [weak self, doses] in
            let pillsByDay = await doses.pillHistory(onDays: days)
            guard !Task.isCancelled, let self else { return }

            let todaysPills = pillsByDay[today] ?? []
            self.totalCount = todaysPills.count
            self.takenCount = todaysPills.filter(\.isTaken).count
            self.streakDays = StreakRules.streak(pillsByDay: pillsByDay, today: today, calendar: calendar)
        }
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
