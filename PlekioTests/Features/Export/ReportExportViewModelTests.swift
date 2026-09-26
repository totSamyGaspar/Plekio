//
//  ReportExportViewModelTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 19.09.2026.
//

import Testing
import Foundation
import SwiftData
@testable import Plekio

@MainActor
@Suite("ReportExportViewModel")
struct ReportExportViewModelTests {

    // MARK: - Helpers

    @discardableResult
    private func seed(_ db: DatabaseService) -> TreatmentCourse {
        let course = TreatmentCourse(
            name: "Course",
            startDate: testDate(2026, 6, 1),
            endDate: testDate(2026, 6, 10)
        )
        course.medications.append(
            MedicationItem(
                id: UUID(),
                name: "Bisoprolol",
                formSystemImage: "pills.fill",
                dosage: 1,
                timesOfDay: [testDate(2000, 1, 1, 9, 0)],
                frequencyDays: 1
            )
        )
        db.context.insert(course)
        try? db.context.save()
        return course
    }

    // MARK: - Selection

    @Test("The screen opens with every course selected for export")
    func testEveryCourseIsSelectedToBeginWith() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        let course = seed(db)

        let viewModel = ReportExportViewModel(database: db, images: StubImageLoader(), errors: SpyErrorReporter(), profile: { .empty })
        viewModel.load()

        #expect(viewModel.courses.map(\.id) == [course.id])
        #expect(viewModel.selection.courseIds == [course.id])
    }

    @Test("With no section selected there is nothing to export")
    func testNothingToExportWithoutSections() async throws {
        let db = DatabaseService(inMemoryForTesting: true)

        let viewModel = ReportExportViewModel(database: db, images: StubImageLoader(), errors: SpyErrorReporter(), profile: { .empty })
        #expect(viewModel.canExport)

        for section in ReportSection.allCases {
            viewModel.toggle(section)
        }
        #expect(viewModel.canExport == false)
    }

    // Otherwise the share button would send a file built before the last change.
    @Test("Any change to the selection discards the already built file")
    func testChangingTheSelectionDiscardsTheDocument() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        seed(db)

        let viewModel = ReportExportViewModel(database: db, images: StubImageLoader(), errors: SpyErrorReporter(), profile: { .empty })
        viewModel.load()

        await viewModel.makeDocument()

        let document = try #require(viewModel.document)
        defer { try? FileManager.default.removeItem(at: document) }
        #expect(FileManager.default.fileExists(atPath: document.path))

        viewModel.toggle(.diary)

        #expect(viewModel.document == nil)
    }

    // MARK: - Export

    @Test("The export reaches a file on disk")
    func testMakeDocumentWritesAFile() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        seed(db)

        let viewModel = ReportExportViewModel(database: db, images: StubImageLoader(), errors: SpyErrorReporter(), profile: { .empty })
        viewModel.load()
        viewModel.selection.from = testDate(2026, 6, 1)
        viewModel.selection.to = testDate(2026, 6, 10)

        await viewModel.makeDocument()

        let document = try #require(viewModel.document)
        defer { try? FileManager.default.removeItem(at: document) }

        #expect(document.pathExtension == "pdf")
        #expect(viewModel.isWorking == false)
    }
}
