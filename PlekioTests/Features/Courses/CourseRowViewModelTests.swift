//
//  CourseRowViewModelTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 19.09.2026.
//

import Testing
import Foundation
import SwiftData
@testable import Plekio

@MainActor
@Suite("CourseRowViewModel")
struct CourseRowViewModelTests {

    // MARK: - Helpers

    private func course(_ db: DatabaseService, named names: [String]) -> TreatmentCourse {
        let course = TreatmentCourse(
            name: "Course",
            startDate: testDate(2026, 6, 1),
            endDate: testDate(2026, 6, 10)
        )

        for (index, name) in names.enumerated() {
            course.medications.append(
                MedicationItem(
                    id: UUID(),
                    name: name,
                    formSystemImage: "pills.fill",
                    dosage: index + 1,
                    timesOfDay: [testDate(2000, 1, 1, 9, 0)],
                    frequencyDays: 1
                )
            )
        }

        db.context.insert(course)
        try? db.context.save()
        return course
    }

    // MARK: - Medications

    // SwiftData to-many relationships are unordered, so the list must be sorted explicitly.
    @Test("Medications are listed alphabetically, not in relationship order")
    func testMedicationsAreSortedByName() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        let course = course(db, named: ["Omeprazole", "Aspirin", "Ibuprofen"])

        let viewModel = CourseRowViewModel(course: CourseSnapshot(course), time: SystemTime())

        #expect(viewModel.medications.map(\.name) == ["Aspirin", "Ibuprofen", "Omeprazole"])
    }

    @Test("Every medication in the list has a dosage")
    func testEveryMedicationCarriesItsDosage() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        let course = course(db, named: ["Aspirin", "Bisoprolol"])

        let viewModel = CourseRowViewModel(course: CourseSnapshot(course), time: SystemTime())

        #expect(viewModel.medications.map(\.dosage) == [1, 2])
        #expect(viewModel.medicationsCount == 2)
    }

    @Test("A course without medications yields an empty list, not a crash")
    func testAnEmptyCourseHasNoMedications() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        let course = course(db, named: [])

        let viewModel = CourseRowViewModel(course: CourseSnapshot(course), time: SystemTime())

        #expect(viewModel.medications.isEmpty)
        #expect(viewModel.medicationsCount == 0)
    }
}
