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
            name: "Blood pressure course",
            startDate: testDate(2026, 6, 1),
            endDate: testDate(2026, 6, 10),
            medications: [
                MedicationReport(
                    name: "Bisoprolol",
                    dosage: 1,
                    minutesOfDay: [9 * 60],
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
            mood: "Good",
            moodScore: 4,
            energyLevel: 4,
            discomfortLevel: 1,
            sleepHours: 7.5,
            sleepQuality: "good",
            waterGlasses: waterGlasses,
            symptoms: ["headache"],
            notes: "Feeling steady",
            photoIds: [],
            isQuickLog: isQuickLog
        )
    }

    // MARK: - Header

    @Test("Profile details go into the document header")
    func testProfileIsPrintedInTheHeader() async throws {
        let profile = UserProfile(
            name: "Edward Gasparian",
            birthDate: testDate(1990, 6, 15),
            allergies: "penicillin",
            conditions: "hypertension"
        )

        let text = try text(of: report(profile: profile, courses: [course()]))

        #expect(text.contains("Edward Gasparian"))
        #expect(text.contains("penicillin"))
        #expect(text.contains("hypertension"))
    }

    // Empty labels would read as missing data rather than data never asked for.
    @Test("An empty profile prints no labels without values")
    func testAnEmptyProfilePrintsNoLabels() async throws {
        let text = try text(of: report(courses: [course()]))

        #expect(text.contains(String(localized: "Allergies")) == false)
        #expect(text.contains(String(localized: "Date of birth")) == false)
    }

    // MARK: - Medications

    @Test("Medications and adherence go into the report")
    func testMedicationsAndAdherenceArePrinted() async throws {
        let text = try text(of: report(courses: [course()]))

        #expect(text.contains("Blood pressure course"))
        #expect(text.contains("Bisoprolol"))

        // 3 taken out of 4 settled.
        #expect(text.contains(0.75.formatted(.percent.precision(.fractionLength(0)))))
    }

    // Long courses can carry hundreds of misses; the list is capped to stay readable.
    @Test("A long exceptions list is truncated and says how many it hid")
    func testExceptionsAreCapped() async throws {
        let exceptions = (1...20).map {
            DoseException(time: testDate(2026, 6, $0, 9, 0), kind: .missed)
        }

        let text = try text(of: report(courses: [course(exceptions: exceptions)]))

        #expect(text.contains(String(localized: "\(8) more")))
    }

    // MARK: - Blood pressure

    @Test("Blood-pressure readings go into the table")
    func testPressureRowsArePrinted() async throws {
        let readings = [
            PressureReading(measuredAt: testDate(2026, 6, 2, 8, 0), systolic: 137, diastolic: 91, pulse: 58)
        ]

        let text = try text(of: report(pressure: readings))

        #expect(text.contains("137/91"))
        #expect(text.contains("58"))
    }

    // MARK: - Diary

    @Test("A quick entry doesn't print sleep and water nobody entered")
    func testQuickLogOmitsMeasuresNobodyEntered() async throws {
        let quick = try text(of: report(diary: [diaryDay(waterGlasses: 42, isQuickLog: true)]))
        #expect(quick.contains("Good"))
        #expect(quick.contains("42") == false)

        let full = try text(of: report(diary: [diaryDay(waterGlasses: 42, isQuickLog: false)]))
        #expect(full.contains("42"))
    }

    // MARK: - Empty

    @Test("A report without entries says so instead of printing a blank page")
    func testAnEmptyReportSaysSo() async throws {
        let text = try text(of: report())

        #expect(text.contains(String(localized: "No records for the selected period")))
    }

    // MARK: - The finished file

    @Test("The file has a title and an outline by section")
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

    @Test("The report is drawn and written off the main thread")
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
