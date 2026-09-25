//
//  CourseRepositoryTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("CourseRepository Tests")
struct CourseRepositoryTests {

    // MARK: - Helpers

    private func medication(_ name: String) -> MedicationItem {
        MedicationItem(
            id: UUID(), name: name, formSystemImage: "pills.fill",
            dosage: 1, timesOfDay: [Date()], frequencyDays: 1
        )
    }

    // MARK: - Snapshots

    @Test("снимок копирует курс и сортирует лекарства по имени")
    func snapshotCopiesAndSortsMedications() throws {
        let db = MockDatabaseService()
        let course = TreatmentCourse(name: "Курс", startDate: Date(), endDate: Date().addingTimeInterval(86400))
        course.medications.append(contentsOf: [medication("Магний"), medication("аспирин"), medication("Витамин D")])
        db.coursesToReturn = [course]

        let snapshot = try #require(SwiftDataCourseRepository(store: db).course(id: course.id))

        #expect(snapshot.name == "Курс")
        #expect(snapshot.medications.map(\.name) == ["аспирин", "Витамин D", "Магний"])
    }

    @Test("снимок не меняется, когда меняется модель")
    func snapshotIsAValue() throws {
        let db = MockDatabaseService()
        let course = TreatmentCourse(name: "До", startDate: Date(), endDate: Date().addingTimeInterval(86400))
        db.coursesToReturn = [course]
        let repository = SwiftDataCourseRepository(store: db)

        let snapshot = try #require(repository.course(id: course.id))
        course.name = "После"

        #expect(snapshot.name == "До")
        #expect(repository.course(id: course.id)?.name == "После")
    }

    // MARK: - Writes

    @Test("запись по id удалённой записи — ошибка, а не тихий пропуск")
    func writeToMissingRecordThrows() {
        let repository = SwiftDataCourseRepository(store: MockDatabaseService())

        #expect(throws: CourseRepositoryError.self) {
            try repository.updateCourse(id: UUID(), name: "X", startDate: Date(), endDate: Date())
        }
        #expect(throws: CourseRepositoryError.self) {
            try repository.deleteMedication(id: UUID())
        }
    }

    @Test("лекарство находится по id через его курс")
    func medicationIsFoundById() throws {
        let db = MockDatabaseService()
        let course = TreatmentCourse(name: "Курс", startDate: Date(), endDate: Date().addingTimeInterval(86400))
        let med = medication("Ибупрофен")
        course.medications.append(med)
        db.coursesToReturn = [course]

        try SwiftDataCourseRepository(store: db).deleteMedication(id: med.id)

        #expect(db.deletedMedication === med)
    }
}
