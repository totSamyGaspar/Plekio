//
//  TimeSourceTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Testing
import Foundation
import SwiftData
@testable import Plekio

@MainActor
@Suite("Time-dependent rules")
struct TimeSourceTests {

    // MARK: - Helpers

    private let calendar = Calendar.current

    /// Far from the real clock, so any stray `Date()` makes these tests fail.
    private var slot: Date {
        calendar.date(from: DateComponents(year: 2030, month: 6, day: 10, hour: 9))!
    }

    private func dose(at time: Date) -> PillDose {
        PillDose(medicationId: UUID(), name: "Dose", dosage: 1, formSystemImage: "pills.fill",
                 time: time, period: .morning)
    }

    // MARK: - PillDose

    @Test("A dose becomes missed exactly when the grace period ends")
    func missedStartsAfterTheGracePeriod() {
        let pill = dose(at: slot)
        let graceEnd = slot.addingTimeInterval(DoseSchedule.missedGrace)

        #expect(!pill.isMissed(at: graceEnd))
        #expect(pill.isMissed(at: graceEnd.addingTimeInterval(1)))
    }

    @Test("An evening dose can be logged the same morning, tomorrow's can't")
    func loggableIsTodayOrPast() {
        let morning = calendar.date(from: DateComponents(year: 2030, month: 6, day: 10, hour: 7))!
        let tonight = calendar.date(from: DateComponents(year: 2030, month: 6, day: 10, hour: 21))!
        let tomorrow = calendar.date(from: DateComponents(year: 2030, month: 6, day: 11, hour: 9))!

        #expect(dose(at: tonight).isLoggable(at: morning, calendar: calendar))
        #expect(!dose(at: tomorrow).isLoggable(at: morning, calendar: calendar))
    }

    // MARK: - Storage

    @Test("The take time is written from the injected clock, not the system one")
    func takenAtComesFromTheInjectedClock() throws {
        let clock = FixedTime(slot.addingTimeInterval(15 * 60))
        let db = DatabaseService(inMemoryForTesting: true, photos: FakePhotoStore(), errors: SpyErrorReporter(), time: clock)

        let course = TreatmentCourse(name: "Course", startDate: slot, endDate: slot)
        let med = MedicationItem(id: UUID(), name: "Ibuprofen", formSystemImage: "pills.fill",
                                 dosage: 1, timesOfDay: [slot], frequencyDays: 1)
        course.medications.append(med)
        db.context.insert(course)
        try db.context.save()

        try db.togglePill(medicationId: med.id, scheduledTime: slot)

        #expect(med.logs.first?.status.takenAt == clock.now)
    }

    // MARK: - View models

    @Test("A course that ended yesterday by the injected clock moves to history")
    func courseListSplitsByTheInjectedDay() {
        let today = slot
        let yesterday = today.addingTimeInterval(-86400)
        let db = MockDatabaseService()
        let running = TreatmentCourse(name: "Running", startDate: yesterday, endDate: today)
        let finished = TreatmentCourse(name: "Ended", startDate: yesterday, endDate: yesterday)
        db.coursesToReturn = [running, finished]

        let vm = CoursesListViewModel(
            courses: SwiftDataCourseRepository(store: db),
            courseEditing: CourseEditingUseCase(dbService: db, notificationService: MockNotificationService()),
            errors: SpyErrorReporter(),
            changes: db.changes,
            time: FixedTime(today)
        )

        #expect(vm.activeCourses.map(\.name) == ["Running"])
        #expect(vm.historyCourses.map(\.name) == ["Ended"])
    }

    @Test("The dashboard opens on the injected clock's today")
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
