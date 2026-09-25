//
//  CourseRowViewModelTests.swift
//  PlekioTests
//
//  A finished course cannot be opened, so its row in History is the only place
//  the prescriptions are still visible. These pin down that the list is there,
//  carries the dosages, and comes back in the same order every time.
//

import Testing
import Foundation
import SwiftData
@testable import Plekio

@MainActor
@Suite("CourseRowViewModel")
struct CourseRowViewModelTests {

    private func course(_ db: DatabaseService, named names: [String]) -> TreatmentCourse {
        let course = TreatmentCourse(
            name: "Курс",
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

    // SwiftData does not define an order for a to-many relationship, so a list
    // taken as it comes can be shuffled between launches.
    @Test("препараты перечислены по алфавиту, а не в порядке связи")
    func testMedicationsAreSortedByName() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        let course = course(db, named: ["Омепразол", "Аспирин", "Ибупрофен"])

        let viewModel = CourseRowViewModel(course: course)

        #expect(viewModel.medications.map(\.name) == ["Аспирин", "Ибупрофен", "Омепразол"])
    }

    @Test("у каждого препарата в списке есть дозировка")
    func testEveryMedicationCarriesItsDosage() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        let course = course(db, named: ["Аспирин", "Бисопролол"])

        let viewModel = CourseRowViewModel(course: course)

        #expect(viewModel.medications.map(\.dosage) == [1, 2])
        #expect(viewModel.medicationsCount == 2)
    }

    @Test("курс без препаратов даёт пустой список, а не падение")
    func testAnEmptyCourseHasNoMedications() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        let course = course(db, named: [])

        let viewModel = CourseRowViewModel(course: course)

        #expect(viewModel.medications.isEmpty)
        #expect(viewModel.medicationsCount == 0)
    }
}
