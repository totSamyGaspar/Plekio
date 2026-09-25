//
//  ReportRendererTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 19.09.2026.
//

import Testing
import Foundation
import PDFKit
import UIKit
@testable import Plekio

@MainActor
@Suite("ReportRenderer")
struct ReportRendererTests {

    // MARK: - Fixtures

    private func report(
        profile: UserProfile = .empty,
        courses: [CourseReport] = [],
        pressure: [PressureReading] = [],
        diary: [DiaryDay] = []
    ) -> ReportData {
        ReportData(
            profile: profile,
            from: testDate(2026, 6, 1),
            to: testDate(2026, 6, 30),
            generatedAt: testDate(2026, 7, 1),
            courses: courses,
            pressure: pressure,
            diary: diary
        )
    }

    private func text(of data: ReportData) throws -> String {
        let rendered = ReportRenderer().render(data)
        let document = try #require(PDFDocument(data: rendered.data))
        return try #require(document.string)
    }

    private func course(
        adherence: Adherence = Adherence(taken: 3, skipped: 1, missed: 0),
        exceptions: [DoseException] = []
    ) -> CourseReport {
        CourseReport(
            name: "Курс от давления",
            startDate: testDate(2026, 6, 1),
            endDate: testDate(2026, 6, 10),
            medications: [
                MedicationReport(
                    name: "Бисопролол",
                    dosage: 1,
                    timesOfDay: [testDate(2000, 1, 1, 9, 0)],
                    frequencyDays: 1,
                    adherence: adherence,
                    exceptions: exceptions
                )
            ]
        )
    }

    private func diaryDay(waterGlasses: Int, isQuickLog: Bool) -> DiaryDay {
        DiaryDay(
            date: testDate(2026, 6, 2, 21, 0),
            mood: "Хорошее",
            moodScore: 4,
            energyLevel: 4,
            discomfortLevel: 1,
            sleepHours: 7.5,
            sleepQuality: "good",
            waterGlasses: waterGlasses,
            symptoms: ["головная боль"],
            notes: "Самочувствие ровное",
            photoIds: [],
            isQuickLog: isQuickLog
        )
    }

    // MARK: - Header

    @Test("данные профиля попадают в шапку документа")
    func testProfileIsPrintedInTheHeader() async throws {
        let profile = UserProfile(
            name: "Едуард Гаспарян",
            birthDate: testDate(1990, 6, 15),
            allergies: "пеніцилін",
            conditions: "гіпертонія"
        )

        let text = try text(of: report(profile: profile, courses: [course()]))

        #expect(text.contains("Едуард Гаспарян"))
        #expect(text.contains("пеніцилін"))
        #expect(text.contains("гіпертонія"))
    }

    // Empty labels would read as missing data rather than data never asked for.
    @Test("пустой профиль не печатает подписи без значений")
    func testAnEmptyProfilePrintsNoLabels() async throws {
        let text = try text(of: report(courses: [course()]))

        #expect(text.contains(String(localized: "Allergies")) == false)
        #expect(text.contains(String(localized: "Date of birth")) == false)
    }

    // MARK: - Medications

    @Test("препараты и доля соблюдения попадают в отчёт")
    func testMedicationsAndAdherenceArePrinted() async throws {
        let text = try text(of: report(courses: [course()]))

        #expect(text.contains("Курс от давления"))
        #expect(text.contains("Бисопролол"))

        // 3 taken out of 4 settled.
        #expect(text.contains(0.75.formatted(.percent.precision(.fractionLength(0)))))
    }

    // Long courses can carry hundreds of misses; the list is capped to stay readable.
    @Test("длинный список исключений обрезается и говорит, сколько скрыл")
    func testExceptionsAreCapped() async throws {
        let exceptions = (1...20).map {
            DoseException(time: testDate(2026, 6, $0, 9, 0), kind: .missed)
        }

        let text = try text(of: report(courses: [course(exceptions: exceptions)]))

        #expect(text.contains(String(localized: "\(8) more")))
    }

    // MARK: - Blood pressure

    @Test("показания давления попадают в таблицу")
    func testPressureRowsArePrinted() async throws {
        let readings = [
            PressureReading(measuredAt: testDate(2026, 6, 2, 8, 0), systolic: 137, diastolic: 91, pulse: 58)
        ]

        let text = try text(of: report(pressure: readings))

        #expect(text.contains("137/91"))
        #expect(text.contains("58"))
    }

    // MARK: - Diary

    @Test("быстрая запись не печатает сон и воду, которых никто не вводил")
    func testQuickLogOmitsMeasuresNobodyEntered() async throws {
        let quick = try text(of: report(diary: [diaryDay(waterGlasses: 42, isQuickLog: true)]))
        #expect(quick.contains("Хорошее"))
        #expect(quick.contains("42") == false)

        let full = try text(of: report(diary: [diaryDay(waterGlasses: 42, isQuickLog: false)]))
        #expect(full.contains("42"))
    }

    // MARK: - Empty

    @Test("отчёт без записей говорит об этом, а не выходит пустой страницей")
    func testAnEmptyReportSaysSo() async throws {
        let text = try text(of: report())

        #expect(text.contains(String(localized: "No records for the selected period")))
    }

    // MARK: - The finished file

    @Test("у файла есть название и оглавление по разделам")
    func testWrittenFileCarriesTitleAndOutline() async throws {
        let data = report(
            courses: [course()],
            pressure: [PressureReading(measuredAt: testDate(2026, 6, 2, 8, 0), systolic: 120, diastolic: 80, pulse: nil)]
        )

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReportDocumentTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = try ReportDocument.write(ReportRenderer().render(data), for: data, in: directory)
        let written = try #require(PDFDocument(url: url))

        let title = written.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String
        #expect(title?.isEmpty == false)

        // Medications and pressure only; no diary, so no bookmark for it.
        #expect(written.outlineRoot?.numberOfChildren == 2)
    }

    // MARK: - Off the main actor

    @Test("отчёт рисуется и записывается вне главного потока")
    func rendersOffTheMainThread() async throws {
        // Rendering runs detached; the pipeline must not gain a main-actor dependency.
        let data = report()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PlekioReportTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let (url, onMain) = try await Task.detached {
            let rendered = ReportRenderer().render(data)
            let url = try ReportDocument.write(rendered, for: data, in: directory)
            return (url, Self.isMainThread())
        }.value

        #expect(onMain == false)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    // MARK: - Helpers

    /// `Thread.isMainThread` is unavailable in async contexts, so it is read via a sync function.
    nonisolated private static func isMainThread() -> Bool {
        Thread.isMainThread
    }
}
