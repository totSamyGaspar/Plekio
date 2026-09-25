//
//  NewTreatmentViewModelTests.swift
//  PlekioTests
//
//  Tests for the new-course creation screen. The screen only writes; the
//  reminder rebuild that follows a save is ReminderSyncCoordinator's, and is
//  tested there.
//

import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("NewTreatmentViewModel Tests")
struct NewTreatmentViewModelTests {

    @Test("saveCourse сохраняет курс через базу")
    func testSaveCourseDelegatesToTheDatabase() async throws {
        let mockDB = MockDatabaseService()

        let vm = NewTreatmentViewModel(courseEditing: CourseEditingUseCase(dbService: mockDB, notificationService: MockNotificationService()), errors: SpyErrorReporter())
        vm.courseName = "Витамины"
        vm.addMedication(MedicationDraft(name: "Витамин D"))

        #expect(vm.saveCourse() == true)
        #expect(mockDB.didCallSaveCourse == true)
        #expect(mockDB.savedCourseName == "Витамины")
    }

    @Test("isSaveEnabled requires a non-empty course name and at least one medication")
    func testIsSaveEnabledValidation() async throws {
        let mockDB = MockDatabaseService()
        let vm = NewTreatmentViewModel(courseEditing: CourseEditingUseCase(dbService: mockDB, notificationService: MockNotificationService()), errors: SpyErrorReporter())

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
