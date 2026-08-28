//
//  StatisticsViewModel.swift
//  PillFlow
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
    @Published var lowStockItems: [MedicationItem] = []
    
    private let dbService: DatabaseServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    private static let streakLookbackDays = 30
    /// Fraction of a day's doses that has to be logged for the day to count.
    private static let streakThreshold = 0.9
    
    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(takenCount) / Double(totalCount)
    }
    
    init(dbService: DatabaseServiceProtocol) {
        self.dbService = dbService
        loadStats()

        NotificationCenter.default.publisher(for: .databaseDidUpdate)
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.loadStats() }
            .store(in: &cancellables)
    }
    
    func loadStats() {
        let allCourses = dbService.fetchAllCourses()
        
        let todaysPills = dbService.fetchPills(for: Date(), preFetchedCourses: allCourses)
        self.totalCount = todaysPills.count
        self.takenCount = todaysPills.filter { $0.isTaken }.count

        // Unfinished courses only: there is no point reminding the user to restock
        // a medication for a course that has already ended.
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let activeCourses = allCourses.filter {
            Calendar.current.startOfDay(for: $0.endDate) >= startOfToday
        }
        self.lowStockItems = activeCourses
            .flatMap(\.medications)
            .filter { $0.stockCount <= $0.lowStockThreshold }

        self.streakDays = calculateStreak(courses: allCourses)
    }
    
    // MARK: - Streak

    /// How many consecutive days adherence stayed at or above `streakThreshold`.
    ///
    /// Today counts once it is already fully logged, but it never breaks the
    /// streak: the day is not over, and recording it as a miss at 10am would be
    /// lying to the user.
    ///
    /// The denominator comes from the schedule (`fetchPills`), not from the number
    /// of `DoseLog` records found. `total` used to be counted from the logs, and a
    /// log exists only once a dose has been logged: a "took 1 of 3" day scored
    /// 1/1 = 100%, so the streak grew more reliably the fewer doses a person
    /// logged.
    private func calculateStreak(courses: [TreatmentCourse]) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var streak = 0

        // Today can only add: logged in full, the streak is already 1 without
        // waiting for midnight; not logged, the day is simply skipped.
        if let todayAdherence = adherence(on: today, courses: courses),
           todayAdherence >= Self.streakThreshold {
            streak += 1
        }

        // Backwards from yesterday: those days are closed and can break the streak.
        for offset in 1...Self.streakLookbackDays {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { break }

            // A day with nothing scheduled neither breaks nor extends the streak —
            // there is nothing to measure. Otherwise a once-a-week course could never
            // build one at all.
            guard let dayAdherence = adherence(on: day, courses: courses) else { continue }
            guard dayAdherence >= Self.streakThreshold else { break }

            streak += 1
        }

        return streak
    }

    /// Fraction of the day's doses that were logged; `nil` if nothing was scheduled.
    private func adherence(on day: Date, courses: [TreatmentCourse]) -> Double? {
        let scheduled = dbService.fetchPills(for: day, preFetchedCourses: courses)
        guard !scheduled.isEmpty else { return nil }
        let taken = scheduled.filter(\.isTaken).count
        return Double(taken) / Double(scheduled.count)
    }
    
    // MARK: - Refill
    func refill(medication: MedicationItem, amount: Int) {
        guard AppErrorPresenter.shared.run({
            try dbService.refillStock(for: medication, amount: amount)
        }) else { return }

        loadStats()
    }
}
