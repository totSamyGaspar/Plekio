//
//  TimeSourceTests.swift
//  PlekioTests
//
//  The edges of the time rules, pinned with a fixed clock — the cases that
//  could only be tested by waiting while the rules read Date() themselves.
//

import Testing
import Foundation
import SwiftData
@testable import Plekio

@MainActor
@Suite("Time-dependent rules")
struct TimeSourceTests {

    private let calendar = Calendar.current

    /// 10 June 2030, 09:00 — far from the real clock, so a rule that still
    /// reads Date() somewhere fails these tests instead of passing by luck.
    private var slot: Date {
        calendar.date(from: DateComponents(year: 2030, month: 6, day: 10, hour: 9))!
    }

    private func dose(at time: Date) -> PillDose {
        PillDose(medicationId: UUID(), name: "Доза", dosage: 1, formSystemImage: "pills.fill",
                 time: time, period: .morning)
    }

    // MARK: - PillDose

    @Test("доза становится пропущенной ровно после окончания льготного периода")
    func missedStartsAfterTheGracePeriod() {
        let pill = dose(at: slot)
        let graceEnd = slot.addingTimeInterval(DoseSchedule.missedGrace)

        #expect(!pill.isMissed(at: graceEnd))
        #expect(pill.isMissed(at: graceEnd.addingTimeInterval(1)))
    }

    @Test("вечернюю дозу можно отметить утром того же дня, завтрашнюю — нет")
    func loggableIsTodayOrPast() {
        let morning = calendar.date(from: DateComponents(year: 2030, month: 6, day: 10, hour: 7))!
        let tonight = calendar.date(from: DateComponents(year: 2030, month: 6, day: 10, hour: 21))!
        let tomorrow = calendar.date(from: DateComponents(year: 2030, month: 6, day: 11, hour: 9))!

        #expect(dose(at: tonight).isLoggable(at: morning, calendar: calendar))
        #expect(!dose(at: tomorrow).isLoggable(at: morning, calendar: calendar))
    }

    // MARK: - Storage

    @Test("время приёма записывается по переданным часам, а не по системным")
    func takenAtComesFromTheInjectedClock() throws {
        let clock = FixedTime(slot.addingTimeInterval(15 * 60))
        let db = DatabaseService(inMemoryForTesting: true, photos: FakePhotoStore(), errors: SpyErrorReporter(), time: clock)

        let course = TreatmentCourse(name: "Курс", startDate: slot, endDate: slot)
        let med = MedicationItem(id: UUID(), name: "Ибупрофен", formSystemImage: "pills.fill",
                                 dosage: 1, timesOfDay: [slot], frequencyDays: 1)
        course.medications.append(med)
        db.context.insert(course)
        try db.context.save()

        try db.togglePill(medicationId: med.id, scheduledTime: slot)

        // Exactly the clock's time: the lateness of this dose is now a known number.
        #expect(med.logs.first?.status.takenAt == clock.now)
    }

    // MARK: - View models

    @Test("курс, закончившийся вчера по переданным часам, уходит в историю")
    func courseListSplitsByTheInjectedDay() {
        let today = slot
        let yesterday = today.addingTimeInterval(-86400)
        let db = MockDatabaseService()
        let running = TreatmentCourse(name: "Идёт", startDate: yesterday, endDate: today)
        let finished = TreatmentCourse(name: "Закончился", startDate: yesterday, endDate: yesterday)
        db.coursesToReturn = [running, finished]

        let vm = CoursesListViewModel(
            courses: SwiftDataCourseRepository(store: db),
            courseEditing: CourseEditingUseCase(dbService: db, notificationService: MockNotificationService()),
            errors: SpyErrorReporter(),
            time: FixedTime(today)
        )

        #expect(vm.activeCourses.map(\.name) == ["Идёт"])
        #expect(vm.historyCourses.map(\.name) == ["Закончился"])
    }

    @Test("дашборд открывается на «сегодня» переданных часов")
    func dashboardStartsOnTheInjectedDay() {
        let db = MockDatabaseService()
        let vm = DashboardViewModel(
            dbService: db,
            doseLogging: DoseLoggingUseCase(dbService: db, notificationService: MockNotificationService()),
            errors: SpyErrorReporter(),
            time: FixedTime(slot)
        )

        #expect(vm.selectedDate == slot)
        #expect(vm.weekDates.first == calendar.startOfDay(for: slot))
    }
}
