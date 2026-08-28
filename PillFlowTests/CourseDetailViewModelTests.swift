//
//  CourseDetailViewModelTests.swift
//  PillFlowTests
//
//  Tests for the course detail screen: initial state derived from the
//  passed-in course, and that adding/deleting a medication goes through
//  DatabaseService and NotificationServiceProtocol rather than touching
//  SwiftData or UNUserNotificationCenter directly.
//

import Testing
import Foundation
@testable import PillFlow

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
            name: "Антибиотики",
            startDate: startDate,
            endDate: endDate
        )

        let vm = CourseDetailViewModel(course: dummyCourse, dbService: mockDB, notificationService: mockNotifications)

        #expect(vm.courseName == "Антибиотики")
        #expect(vm.startDate == startDate)
        #expect(vm.endDate == endDate)
        #expect(vm.medications.isEmpty)
    }

    // MARK: - addNewMedication

    @Test("addNewMedication saves the medication to the DB and reschedules pushes via the protocol")
    func testAddNewMedicationTriggersSaveAndReschedule() async throws {
        let mockDB = MockDatabaseService()
        let mockNotifications = MockNotificationService()

        let course = TreatmentCourse(name: "Витамины", startDate: Date(), endDate: Date().addingTimeInterval(86400 * 30))
        mockDB.coursesToReturn = [course]

        let vm = CourseDetailViewModel(course: course, dbService: mockDB, notificationService: mockNotifications)
        let draft = MedicationDraft(name: "Витамин D")

        vm.addNewMedication(draft)

        #expect(mockDB.addedMedicationDraft?.name == "Витамин D")
        #expect(mockDB.addedToCourse === course)
        #expect(mockNotifications.didCallRemoveAllPending == true)
        #expect(mockNotifications.scheduledCourses != nil)
    }

    // MARK: - deleteMedication

    @Test("deleteMedication cancels notifications and removes the medication from the DB")
    func testDeleteMedicationCancelsNotificationsAndDeletes() async throws {
        let mockDB = MockDatabaseService()
        let mockNotifications = MockNotificationService()

        let course = TreatmentCourse(name: "Курс", startDate: Date(), endDate: Date().addingTimeInterval(86400 * 10))
        let med = MedicationItem(
            id: UUID(),
            name: "Ибупрофен",
            formSystemImage: "pills.fill",
            dosage: 1,
            timesOfDay: [Date()],
            frequencyDays: 1
        )
        course.medications.append(med)

        let vm = CourseDetailViewModel(course: course, dbService: mockDB, notificationService: mockNotifications)

        vm.deleteMedication(at: IndexSet(integer: 0))

        #expect(mockDB.deletedMedication === med)
        #expect(mockNotifications.cancelledMedicationIds.contains(med.id))
        #expect(vm.medications.isEmpty)
    }
}
