//
//  StatisticsViewModelTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 28.08.2026.
//

import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("StatisticsViewModel")
struct StatisticsViewModelTests {

    // MARK: - Helpers

    private func dose(taken: Bool, at time: Date) -> PillDose {
        PillDose(
            medicationId: UUID(),
            name: "Aspirin",
            dosage: 1,
            form: .pill,
            time: time,
            period: .morning,
            status: taken ? .taken(at: time, dispensed: 1) : .pending,
            stockCount: 30,
            lowStockThreshold: 10
        )
    }

    /// Schedule for the day `offset` days ago: `total` doses, `taken` of them taken.
    private func day(_ offset: Int, taken: Int, total: Int) -> (Date, [PillDose]) {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: Date()))!
        let doses = (0..<total).map { index in
            dose(taken: index < taken, at: start.addingTimeInterval(Double(index + 8) * 3600))
        }
        return (start, doses)
    }

    // MARK: - Streak

    @Test("The streak breaks on a day with only some doses taken")
    func testPartiallyTakenDayBreaksStreak() async throws {
        let mockDB = MockDatabaseService()

        let yesterday = day(1, taken: 3, total: 3)
        let dayBefore = day(2, taken: 1, total: 3)
        mockDB.pillsByDay = [yesterday.0: yesterday.1, dayBefore.0: dayBefore.1]

        let vm = StatisticsViewModel(dbService: mockDB, errors: SpyErrorReporter())
        await vm.historyLoad?.value

        #expect(vm.streakDays == 1)
    }

    @Test("A day with nothing scheduled doesn't break the streak")
    func testDayWithoutDosesDoesNotBreakStreak() async throws {
        let mockDB = MockDatabaseService()

        // Dosed every other day, so the day in between has nothing scheduled.
        let first = day(1, taken: 2, total: 2)
        let third = day(3, taken: 2, total: 2)
        mockDB.pillsByDay = [first.0: first.1, third.0: third.1]

        let vm = StatisticsViewModel(dbService: mockDB, errors: SpyErrorReporter())
        await vm.historyLoad?.value

        #expect(vm.streakDays == 2)
    }

    @Test("A fully logged today counts toward the streak at once")
    func testFullyLoggedTodayCountsImmediately() async throws {
        let mockDB = MockDatabaseService()

        let today = day(0, taken: 3, total: 3)
        mockDB.pillsByDay = [today.0: today.1]

        let vm = StatisticsViewModel(dbService: mockDB, errors: SpyErrorReporter())
        await vm.historyLoad?.value

        #expect(vm.streakDays == 1)
    }

    @Test("Today extends the streak instead of restarting it")
    func testTodayExtendsExistingStreak() async throws {
        let mockDB = MockDatabaseService()

        let today = day(0, taken: 2, total: 2)
        let yesterday = day(1, taken: 2, total: 2)
        mockDB.pillsByDay = [today.0: today.1, yesterday.0: yesterday.1]

        let vm = StatisticsViewModel(dbService: mockDB, errors: SpyErrorReporter())
        await vm.historyLoad?.value

        #expect(vm.streakDays == 2)
    }

    @Test("An unlogged today doesn't break the streak; it isn't over yet")
    func testUnloggedTodayDoesNotBreakStreak() async throws {
        let mockDB = MockDatabaseService()

        let today = day(0, taken: 0, total: 3)
        let yesterday = day(1, taken: 3, total: 3)
        mockDB.pillsByDay = [today.0: today.1, yesterday.0: yesterday.1]

        let vm = StatisticsViewModel(dbService: mockDB, errors: SpyErrorReporter())
        await vm.historyLoad?.value

        // Today is not over, so unlogged doses are not a miss yet.
        #expect(vm.streakDays == 1)
    }

    // MARK: - Today and stock

    @Test("Today's progress follows today's schedule")
    func testTodayProgress() async throws {
        let mockDB = MockDatabaseService()

        let today = day(0, taken: 3, total: 4)
        mockDB.pillsByDay = [today.0: today.1]

        let vm = StatisticsViewModel(dbService: mockDB, errors: SpyErrorReporter())
        await vm.historyLoad?.value

        #expect(vm.totalCount == 4)
        #expect(vm.takenCount == 3)
        #expect(vm.progress == 0.75)
    }

    @Test("Low stock comes only from unfinished courses")
    func testLowStockIgnoresFinishedCourses() async throws {
        let mockDB = MockDatabaseService()

        let active = TreatmentCourse(
            name: "Active",
            startDate: Date().addingTimeInterval(-86400),
            endDate: Date().addingTimeInterval(86400 * 5)
        )
        active.medications.append(
            MedicationItem(id: UUID(), name: "Magnesium", form: .pill,
                           dosage: 1, minutesOfDay: [minuteOfDay(Date())], frequencyDays: 1,
                           stockCount: 2, lowStockThreshold: 10)
        )

        let finished = TreatmentCourse(
            name: "Finished",
            startDate: Date().addingTimeInterval(-86400 * 30),
            endDate: Date().addingTimeInterval(-86400 * 2)
        )
        finished.medications.append(
            MedicationItem(id: UUID(), name: "Ibuprofen", form: .pill,
                           dosage: 1, minutesOfDay: [minuteOfDay(Date())], frequencyDays: 1,
                           stockCount: 1, lowStockThreshold: 10)
        )

        mockDB.coursesToReturn = [active, finished]

        let vm = StatisticsViewModel(dbService: mockDB, errors: SpyErrorReporter())
        await vm.historyLoad?.value

        #expect(vm.lowStockItems.map(\.name) == ["Magnesium"])
    }

    // MARK: - Refill

    @Test("A refill finds the medication by the snapshot's id and writes to the store")
    func refillWritesThroughTheRepository() throws {
        let mockDB = MockDatabaseService()
        let course = TreatmentCourse(
            name: "Active",
            startDate: Date().addingTimeInterval(-86400),
            endDate: Date().addingTimeInterval(86400 * 5)
        )
        let med = MedicationItem(id: UUID(), name: "Magnesium", form: .pill,
                                 dosage: 1, minutesOfDay: [minuteOfDay(Date())], frequencyDays: 1,
                                 stockCount: 2, lowStockThreshold: 10)
        course.medications.append(med)
        mockDB.coursesToReturn = [course]
        let errors = SpyErrorReporter()

        let vm = StatisticsViewModel(dbService: mockDB, errors: errors)
        let snapshot = try #require(vm.lowStockItems.first)

        vm.refill(medication: snapshot, amount: 30)

        #expect(mockDB.refilledMedication === med)
        #expect(mockDB.refilledAmount == 30)
        #expect(errors.reported.isEmpty)
    }

    @Test("A failed refill reports an error and doesn't pretend to succeed")
    func failedRefillReportsFalse() throws {
        let mockDB = MockDatabaseService()
        let errors = SpyErrorReporter()
        let vm = StatisticsViewModel(dbService: mockDB, errors: errors)
        // Deleted from the store on another screen.
        let gone = MedicationSnapshot(
            id: UUID(), name: "Magnesium", form: .pill, dosage: 1,
            minutesOfDay: [minuteOfDay(Date())], frequencyDays: 1, stockCount: 2, lowStockThreshold: 10
        )

        let saved = vm.refill(medication: gone, amount: 30)

        #expect(saved == false)
        #expect(errors.reported.count == 1)
        #expect(mockDB.refilledMedication == nil)
    }
}
