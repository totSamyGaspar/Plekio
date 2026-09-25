//
//  CourseEditingUseCaseTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("CourseEditingUseCase Tests")
struct CourseEditingUseCaseTests {

    // MARK: - Properties

    private let day: TimeInterval = 86400

    // MARK: - Editing details

    @Test("правка без изменений ничего не пишет")
    func updateDetailsWithoutChangesIsANoOp() throws {
        let db = MockDatabaseService()
        let useCase = CourseEditingUseCase(dbService: db, notificationService: MockNotificationService())
        let course = TreatmentCourse(name: "Курс", startDate: Date(), endDate: Date().addingTimeInterval(7 * day))

        let wrote = try useCase.updateDetails(of: CourseSnapshot(course), name: course.name, startDate: course.startDate, endDate: course.endDate)

        #expect(wrote == false)
        #expect(db.didCallUpdateCourseDetails == false)
    }

    @Test("правка с изменением пишет")
    func updateDetailsWithChangeWrites() throws {
        let db = MockDatabaseService()
        let useCase = CourseEditingUseCase(dbService: db, notificationService: MockNotificationService())
        let course = TreatmentCourse(name: "Курс", startDate: Date(), endDate: Date().addingTimeInterval(7 * day))

        db.coursesToReturn = [course]

        let wrote = try useCase.updateDetails(of: CourseSnapshot(course), name: "Новое имя", startDate: course.startDate, endDate: course.endDate)

        #expect(wrote == true)
        #expect(db.updatedCourseName == "Новое имя")
    }

    // MARK: - Repeating

    @Test("повтор отклоняется, пока копия курса ещё идёт — даже переименованная")
    func repeatIsRefusedWhileACopyIsRunning() throws {
        let db = MockDatabaseService()
        let useCase = CourseEditingUseCase(dbService: db, notificationService: MockNotificationService())
        let original = TreatmentCourse(
            name: "Антибиотики",
            startDate: Date().addingTimeInterval(-20 * day),
            endDate: Date().addingTimeInterval(-10 * day)
        )
        let runningCopy = TreatmentCourse(
            name: "Другое имя",
            startDate: Date(),
            endDate: Date().addingTimeInterval(5 * day),
            repeatedFromId: original.id
        )
        db.coursesToReturn = [original, runningCopy]

        let repeated = try useCase.repeatCourse(CourseSnapshot(original), startDate: Date(), endDate: Date().addingTimeInterval(7 * day))

        #expect(repeated == false)
        #expect(db.duplicatedCourse == nil)
    }

    @Test("завершённый курс без активной копии повторяется")
    func finishedCourseCanBeRepeated() throws {
        let db = MockDatabaseService()
        let useCase = CourseEditingUseCase(dbService: db, notificationService: MockNotificationService())
        let original = TreatmentCourse(
            name: "Антибиотики",
            startDate: Date().addingTimeInterval(-20 * day),
            endDate: Date().addingTimeInterval(-10 * day)
        )
        db.coursesToReturn = [original]

        let repeated = try useCase.repeatCourse(CourseSnapshot(original), startDate: Date(), endDate: Date().addingTimeInterval(7 * day))

        #expect(repeated == true)
        #expect(db.duplicatedCourse === original)
    }

    // MARK: - Deleting

    @Test("удаление курса снимает показанные напоминания всех его лекарств")
    func deletingACourseClearsItsDeliveredReminders() async throws {
        let db = MockDatabaseService()
        let notifications = MockNotificationService()
        let useCase = CourseEditingUseCase(dbService: db, notificationService: notifications)
        let course = TreatmentCourse(name: "Курс", startDate: Date(), endDate: Date().addingTimeInterval(7 * day))
        let meds = (0..<2).map { index in
            MedicationItem(
                id: UUID(), name: "Лекарство \(index)", formSystemImage: "pills.fill",
                dosage: 1, timesOfDay: [Date()], frequencyDays: 1
            )
        }
        course.medications.append(contentsOf: meds)

        db.coursesToReturn = [course]
        try useCase.deleteCourse(CourseSnapshot(course))

        #expect(db.deletedCourse === course)
        #expect(await waitUntil { notifications.cancelledMedicationIds.count == 2 })
        #expect(Set(notifications.cancelledMedicationIds) == Set(meds.map(\.id)))
        // The pending queue is the coordinator's job, not this one's.
        #expect(notifications.scheduleCallCount == 0)
    }

    // MARK: - Activity

    @Test("курс, который заканчивается сегодня, ещё активен весь день")
    func courseEndingTodayIsActive() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let endsToday = TreatmentCourse(name: "A", startDate: today.addingTimeInterval(-3 * day), endDate: today.addingTimeInterval(60))
        let endedYesterday = TreatmentCourse(name: "B", startDate: today.addingTimeInterval(-3 * day), endDate: today.addingTimeInterval(-60))

        let lateEvening = today.addingTimeInterval(23 * 3600)
        #expect(endsToday.isActive(on: lateEvening, calendar: calendar))
        #expect(!endedYesterday.isActive(on: today, calendar: calendar))
    }
}
