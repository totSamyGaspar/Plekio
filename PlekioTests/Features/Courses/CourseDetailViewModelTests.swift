//
//  CourseDetailViewModelTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 21.08.2026.
//

import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("CourseDetailViewModel Tests")
struct CourseDetailViewModelTests {

    // MARK: - Initial state

    @Test("Initialization assigns the correct initial values from the course")
    func testInitialization() async throws {
        let mockDB = MockDatabaseService()
        let mockNotifications = MockNotificationService()

        let startDate = Date()
        let endDate = Date().addingTimeInterval(86400 * 7)

        let dummyCourse = TreatmentCourse(
            name: "Antibiotics",
            startDate: startDate,
            endDate: endDate
        )

        let vm = CourseDetailViewModel(course: dummyCourse, dbService: mockDB, notificationService: mockNotifications)

        #expect(vm.courseName == "Antibiotics")
        #expect(vm.startDate == startDate)
        #expect(vm.endDate == endDate)
        #expect(vm.medications.isEmpty)
    }

    // MARK: - addNewMedication

    @Test("addNewMedication writes to the store and doesn't rebuild reminders itself")
    func testAddNewMedicationWritesAndLeavesTheRebuildToTheCoordinator() async throws {
        let mockDB = MockDatabaseService()
        let mockNotifications = MockNotificationService()

        let course = TreatmentCourse(name: "Vitamins", startDate: Date(), endDate: Date().addingTimeInterval(86400 * 30))
        mockDB.coursesToReturn = [course]

        let vm = CourseDetailViewModel(course: course, dbService: mockDB, notificationService: mockNotifications)
        let draft = MedicationDraft(name: "Vitamin D")

        vm.addNewMedication(draft)

        #expect(mockDB.addedMedicationDraft?.name == "Vitamin D")
        #expect(mockDB.addedToCourse === course)
        // ReminderSyncCoordinator rebuilds after the `.courses` write; a second rebuild would duplicate it.
        #expect(mockNotifications.scheduleCallCount == 0)
    }

    // MARK: - deleteMedication

    @Test("deleteMedication cancels notifications and removes the medication from the DB")
    func testDeleteMedicationCancelsNotificationsAndDeletes() async throws {
        let mockDB = MockDatabaseService()
        let mockNotifications = MockNotificationService()

        let course = TreatmentCourse(name: "Course", startDate: Date(), endDate: Date().addingTimeInterval(86400 * 10))
        let med = MedicationItem(
            id: UUID(),
            name: "Ibuprofen",
            formSystemImage: "pills.fill",
            dosage: 1,
            timesOfDay: [Date()],
            frequencyDays: 1
        )
        course.medications.append(med)
        // The screen names the medication by id; the store has to be able to find it.
        mockDB.coursesToReturn = [course]

        let vm = CourseDetailViewModel(course: course, dbService: mockDB, notificationService: mockNotifications)

        vm.deleteMedication(at: IndexSet(integer: 0))

        #expect(mockDB.deletedMedication === med)
        #expect(await waitUntil { mockNotifications.cancelledMedicationIds.contains(med.id) })
        #expect(vm.medications.isEmpty)
    }
}
