//
//  NewTreatmentViewModelTests.swift
//  PillFlowTests
//
//  Tests for the new-course creation screen. saveCourse is another spot
//  (alongside CourseDetailViewModel and DashboardViewModel) where rescheduling
//  goes through NotificationServiceProtocol and only considers courses that
//  haven't expired.
//

import Testing
import Foundation
@testable import PillFlow

@MainActor
@Suite("NewTreatmentViewModel Tests")
struct NewTreatmentViewModelTests {

    @Test("saveCourse saves the course and reschedules pushes only for active courses")
    func testSaveCourseDelegatesAndReschedules() async throws {
        let mockDB = MockDatabaseService()
        let mockNotifications = MockNotificationService()

        let activeCourse = TreatmentCourse(name: "Активный", startDate: Date(), endDate: Date().addingTimeInterval(86400 * 5))
        let expiredCourse = TreatmentCourse(name: "Просроченный", startDate: Date().addingTimeInterval(-86400 * 10), endDate: Date().addingTimeInterval(-86400))
        mockDB.coursesToReturn = [activeCourse, expiredCourse]

        let vm = NewTreatmentViewModel(dbService: mockDB, notificationService: mockNotifications)
        vm.courseName = "Витамины"
        vm.addMedication(MedicationDraft(name: "Витамин D"))

        vm.saveCourse()

        #expect(mockDB.didCallSaveCourse == true)
        #expect(mockDB.savedCourseName == "Витамины")
        #expect(await waitUntil { mockNotifications.scheduleCallCount == 1 })
        #expect(mockNotifications.didCallRemoveAllPending == true)
        #expect(mockNotifications.scheduledCourses?.count == 1)
        #expect(mockNotifications.scheduledCourses?.first === activeCourse)
    }

    @Test("isSaveEnabled requires a non-empty course name and at least one medication")
    func testIsSaveEnabledValidation() async throws {
        let mockDB = MockDatabaseService()
        let mockNotifications = MockNotificationService()
        let vm = NewTreatmentViewModel(dbService: mockDB, notificationService: mockNotifications)

        #expect(vm.isSaveEnabled == false)

        vm.courseName = "   " // whitespace only — also counts as empty
        #expect(vm.isSaveEnabled == false)

        vm.courseName = "Курс"
        #expect(vm.isSaveEnabled == false)

        vm.addMedication(MedicationDraft(name: "Аспирин"))
        #expect(vm.isSaveEnabled == true)

        vm.deleteMedication(at: IndexSet(integer: 0))
        #expect(vm.isSaveEnabled == false)
    }
}
