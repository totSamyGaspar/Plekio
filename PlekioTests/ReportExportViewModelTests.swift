//
//  ReportExportViewModelTests.swift
//  PlekioTests
//
//  Mostly one rule: the file on the Share button must always be the file the
//  screen describes. Everything else here is setup around that.
//

import Testing
import Foundation
import SwiftData
@testable import Plekio

@MainActor
@Suite("ReportExportViewModel")
struct ReportExportViewModelTests {

    private func seed(_ db: DatabaseService) -> TreatmentCourse {
        let course = TreatmentCourse(
            name: "Курс",
            startDate: testDate(2026, 6, 1),
            endDate: testDate(2026, 6, 10)
        )
        course.medications.append(
            MedicationItem(
                id: UUID(),
                name: "Бисопролол",
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

    @Test("экран открывается со всеми курсами, отмеченными к выгрузке")
    func testEveryCourseIsSelectedToBeginWith() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        let course = seed(db)

        let viewModel = ReportExportViewModel(database: db, errors: SpyErrorReporter())
        viewModel.load()

        #expect(viewModel.courses.map(\.id) == [course.id])
        #expect(viewModel.selection.courseIds == [course.id])
    }

    @Test("без единого выбранного раздела выгружать нечего")
    func testNothingToExportWithoutSections() async throws {
        let db = DatabaseService(inMemoryForTesting: true)

        let viewModel = ReportExportViewModel(database: db, errors: SpyErrorReporter())
        #expect(viewModel.canExport)

        for section in ReportSection.allCases {
            viewModel.toggle(section)
        }
        #expect(viewModel.canExport == false)
    }

    // The one failure nobody would notice: the screen says one thing, the
    // button shares a file made before the last change.
    @Test("любое изменение выбора выбрасывает уже собранный файл")
    func testChangingTheSelectionDiscardsTheDocument() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        seed(db)

        let viewModel = ReportExportViewModel(database: db, errors: SpyErrorReporter())
        viewModel.load()

        await viewModel.makeDocument()

        let document = try #require(viewModel.document)
        defer { try? FileManager.default.removeItem(at: document) }
        #expect(FileManager.default.fileExists(atPath: document.path))

        viewModel.toggle(.diary)

        #expect(viewModel.document == nil)
    }

    @Test("выгрузка доходит до файла на диске")
    func testMakeDocumentWritesAFile() async throws {
        let db = DatabaseService(inMemoryForTesting: true)
        seed(db)

        let viewModel = ReportExportViewModel(database: db, errors: SpyErrorReporter())
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
