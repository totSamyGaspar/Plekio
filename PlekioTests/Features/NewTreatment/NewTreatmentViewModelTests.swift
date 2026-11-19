//
//  NewTreatmentViewModelTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 22.08.2026.
//

import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("NewTreatmentViewModel Tests")
struct NewTreatmentViewModelTests {

    // MARK: - Saving

    @Test("saveCourse saves the course through the store")
    func testSaveCourseDelegatesToTheDatabase() async throws {
        let mockDB = MockDatabaseService()

        let vm = NewTreatmentViewModel(courseEditing: CourseEditingUseCase(dbService: mockDB, notificationService: MockNotificationService()), errors: SpyErrorReporter())
        vm.courseName = "Vitamins"
        vm.addMedication(MedicationDraft(name: "Vitamin D"))

        #expect(vm.saveCourse() == true)
        #expect(mockDB.didCallSaveCourse == true)
        #expect(mockDB.savedCourseName == "Vitamins")
    }

    // MARK: - Validation

    @Test("isSaveEnabled requires a non-empty course name and at least one medication")
    func testIsSaveEnabledValidation() async throws {
        let mockDB = MockDatabaseService()
        let vm = NewTreatmentViewModel(courseEditing: CourseEditingUseCase(dbService: mockDB, notificationService: MockNotificationService()), errors: SpyErrorReporter())

        #expect(vm.isSaveEnabled == false)

        vm.courseName = "   "
        #expect(vm.isSaveEnabled == false)

        vm.courseName = "Course"
        #expect(vm.isSaveEnabled == false)

        vm.addMedication(MedicationDraft(name: "Aspirin"))
        #expect(vm.isSaveEnabled == true)

        vm.deleteMedication(at: IndexSet(integer: 0))
        #expect(vm.isSaveEnabled == false)
    }

    // MARK: - Dates

    @Test("A new course runs from now for a week, by TimeSource")
    func datesComeFromTimeSource() {
        let now = testDate(2026, 11, 12, 8, 30)
        let vm = NewTreatmentViewModel(
            courseEditing: CourseEditingUseCase(dbService: MockDatabaseService(), notificationService: MockNotificationService()),
            errors: SpyErrorReporter(),
            time: FixedTime(now)
        )

        #expect(vm.startDate == now)
        #expect(vm.endDate == addingDays(7, to: now))
    }
}
