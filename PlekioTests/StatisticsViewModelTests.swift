//
//  StatisticsViewModelTests.swift
//  PlekioTests
//
//  This view model had no coverage at all, and held the nastiest statistics bug:
//  the streak scored adherence against the number of DoseLog rows instead of
//  against the schedule. A log exists only once a dose is logged, so "took 1 of
//  3" scored 1/1 = 100% and the streak grew the fewer doses a person logged.
//

import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("StatisticsViewModel")
struct StatisticsViewModelTests {

    private func dose(taken: Bool, at time: Date) -> PillDose {
        PillDose(
            medicationId: UUID(),
            name: "Аспирин",
            dosage: 1,
            formSystemImage: "pills.fill",
            time: time,
            period: .morning,
            isTaken: taken,
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

    @Test("серия обрывается на дне, где принята только часть назначенных доз")
    func testPartiallyTakenDayBreaksStreak() async throws {
        let mockDB = MockDatabaseService()

        // Yesterday fully taken; the day before, 1 of 3. The old logic scored that
        // day 100% — one log found, and it was taken — so the streak survived.
        let yesterday = day(1, taken: 3, total: 3)
        let dayBefore = day(2, taken: 1, total: 3)
        mockDB.pillsByDay = [yesterday.0: yesterday.1, dayBefore.0: dayBefore.1]

        let vm = StatisticsViewModel(dbService: mockDB, errors: SpyErrorReporter())

        #expect(vm.streakDays == 1)
    }

    @Test("день без назначений серию не обрывает")
    func testDayWithoutDosesDoesNotBreakStreak() async throws {
        let mockDB = MockDatabaseService()

        // Dosed every other day, so the day in between has nothing scheduled.
        let first = day(1, taken: 2, total: 2)
        let third = day(3, taken: 2, total: 2)
        mockDB.pillsByDay = [first.0: first.1, third.0: third.1]

        let vm = StatisticsViewModel(dbService: mockDB, errors: SpyErrorReporter())

        #expect(vm.streakDays == 2)
    }

    @Test("полностью отмеченный сегодняшний день сразу даёт серию")
    func testFullyLoggedTodayCountsImmediately() async throws {
        let mockDB = MockDatabaseService()

        let today = day(0, taken: 3, total: 3)
        mockDB.pillsByDay = [today.0: today.1]

        let vm = StatisticsViewModel(dbService: mockDB, errors: SpyErrorReporter())

        // This used to be 0: the streak started at yesterday, so a fully logged
        // today never counted.
        #expect(vm.streakDays == 1)
    }

    @Test("сегодняшний день продлевает серию, а не начинает её заново")
    func testTodayExtendsExistingStreak() async throws {
        let mockDB = MockDatabaseService()

        let today = day(0, taken: 2, total: 2)
        let yesterday = day(1, taken: 2, total: 2)
        mockDB.pillsByDay = [today.0: today.1, yesterday.0: yesterday.1]

        let vm = StatisticsViewModel(dbService: mockDB, errors: SpyErrorReporter())

        #expect(vm.streakDays == 2)
    }

    @Test("неотмеченный сегодняшний день серию не обрывает — он ещё не закончился")
    func testUnloggedTodayDoesNotBreakStreak() async throws {
        let mockDB = MockDatabaseService()

        let today = day(0, taken: 0, total: 3)
        let yesterday = day(1, taken: 3, total: 3)
        mockDB.pillsByDay = [today.0: today.1, yesterday.0: yesterday.1]

        let vm = StatisticsViewModel(dbService: mockDB, errors: SpyErrorReporter())

        // Nothing logged yet today is not a miss — the day is not over, so
        // yesterday's streak must survive.
        #expect(vm.streakDays == 1)
    }

    @Test("прогресс за сегодня считается по расписанию текущего дня")
    func testTodayProgress() async throws {
        let mockDB = MockDatabaseService()

        let today = day(0, taken: 3, total: 4)
        mockDB.pillsByDay = [today.0: today.1]

        let vm = StatisticsViewModel(dbService: mockDB, errors: SpyErrorReporter())

        #expect(vm.totalCount == 4)
        #expect(vm.takenCount == 3)
        #expect(vm.progress == 0.75)
    }

    @Test("низкий остаток берётся только из незавершённых курсов")
    func testLowStockIgnoresFinishedCourses() async throws {
        let mockDB = MockDatabaseService()

        let active = TreatmentCourse(
            name: "Активный",
            startDate: Date().addingTimeInterval(-86400),
            endDate: Date().addingTimeInterval(86400 * 5)
        )
        active.medications.append(
            MedicationItem(id: UUID(), name: "Магний", formSystemImage: "pills.fill",
                           dosage: 1, timesOfDay: [Date()], frequencyDays: 1,
                           stockCount: 2, lowStockThreshold: 10)
        )

        let finished = TreatmentCourse(
            name: "Завершённый",
            startDate: Date().addingTimeInterval(-86400 * 30),
            endDate: Date().addingTimeInterval(-86400 * 2)
        )
        finished.medications.append(
            MedicationItem(id: UUID(), name: "Ибупрофен", formSystemImage: "pills.fill",
                           dosage: 1, timesOfDay: [Date()], frequencyDays: 1,
                           stockCount: 1, lowStockThreshold: 10)
        )

        mockDB.coursesToReturn = [active, finished]

        let vm = StatisticsViewModel(dbService: mockDB, errors: SpyErrorReporter())

        #expect(vm.lowStockItems.map(\.name) == ["Магний"])
    }

    @Test("пополнение запаса находит лекарство по id снимка и пишет в базу")
    func refillWritesThroughTheRepository() throws {
        let mockDB = MockDatabaseService()
        let course = TreatmentCourse(
            name: "Активный",
            startDate: Date().addingTimeInterval(-86400),
            endDate: Date().addingTimeInterval(86400 * 5)
        )
        let med = MedicationItem(id: UUID(), name: "Магний", formSystemImage: "pills.fill",
                                 dosage: 1, timesOfDay: [Date()], frequencyDays: 1,
                                 stockCount: 2, lowStockThreshold: 10)
        course.medications.append(med)
        mockDB.coursesToReturn = [course]
        let errors = SpyErrorReporter()

        let vm = StatisticsViewModel(dbService: mockDB, errors: errors)
        let snapshot = try #require(vm.lowStockItems.first)

        vm.refill(medication: snapshot, amount: 30)

        // The screen only ever held the snapshot; the repository found the model.
        #expect(mockDB.refilledMedication === med)
        #expect(mockDB.refilledAmount == 30)
        #expect(errors.reported.isEmpty)
    }

    @Test("неудачное пополнение сообщает об ошибке и не выдаёт себя за успех")
    func failedRefillReportsFalse() throws {
        let mockDB = MockDatabaseService()
        let errors = SpyErrorReporter()
        let vm = StatisticsViewModel(dbService: mockDB, errors: errors)
        // A medication the store no longer has — deleted on another screen.
        let gone = MedicationSnapshot(
            id: UUID(), name: "Магний", formSystemImage: "pills.fill", dosage: 1,
            timesOfDay: [Date()], frequencyDays: 1, stockCount: 2, lowStockThreshold: 10
        )

        let saved = vm.refill(medication: gone, amount: 30)

        // The screen shows its success toast only on `true`.
        #expect(saved == false)
        #expect(errors.reported.count == 1)
        #expect(mockDB.refilledMedication == nil)
    }
}
