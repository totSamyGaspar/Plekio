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

    @Test("A snapshot copies the course and sorts medications by name")
    func snapshotCopiesAndSortsMedications() throws {
        let db = MockDatabaseService()
        let course = TreatmentCourse(name: "Course", startDate: Date(), endDate: Date().addingTimeInterval(86400))
        course.medications.append(contentsOf: [medication("Magnesium"), medication("aspirin"), medication("Vitamin D")])
        db.coursesToReturn = [course]

        let snapshot = try #require(SwiftDataCourseRepository(store: db).course(id: course.id))

        #expect(snapshot.name == "Course")
        #expect(snapshot.medications.map(\.name) == ["aspirin", "Magnesium", "Vitamin D"])
    }

    @Test("A snapshot doesn't change when the model does")
    func snapshotIsAValue() throws {
        let db = MockDatabaseService()
        let course = TreatmentCourse(name: "Before", startDate: Date(), endDate: Date().addingTimeInterval(86400))
        db.coursesToReturn = [course]
        let repository = SwiftDataCourseRepository(store: db)

        let snapshot = try #require(repository.course(id: course.id))
        course.name = "After"

        #expect(snapshot.name == "Before")
        #expect(repository.course(id: course.id)?.name == "After")
    }

    // MARK: - Writes

    @Test("Writing by the id of a deleted entry is an error, not a silent no-op")
    func writeToMissingRecordThrows() {
        let repository = SwiftDataCourseRepository(store: MockDatabaseService())

        #expect(throws: CourseRepositoryError.self) {
            try repository.updateCourse(id: UUID(), name: "X", startDate: Date(), endDate: Date())
        }
        #expect(throws: CourseRepositoryError.self) {
            try repository.deleteMedication(id: UUID())
        }
    }

    @Test("A medication is found by id through its course")
    func medicationIsFoundById() throws {
        let db = MockDatabaseService()
        let course = TreatmentCourse(name: "Course", startDate: Date(), endDate: Date().addingTimeInterval(86400))
        let med = medication("Ibuprofen")
        course.medications.append(med)
        db.coursesToReturn = [course]

        try SwiftDataCourseRepository(store: db).deleteMedication(id: med.id)

        #expect(db.deletedMedication === med)
    }
}
