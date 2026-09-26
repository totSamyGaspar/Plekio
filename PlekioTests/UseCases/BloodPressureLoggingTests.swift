//
//  BloodPressureLoggingTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("Blood pressure: rules and saving")
struct BloodPressureLoggingTests {

    // MARK: - Helpers

    private let now = Date(timeIntervalSince1970: 1_780_000_000)

    private func issue(_ systolic: Int, _ diastolic: Int, pulse: Int? = nil,
                       at date: Date? = nil) -> BloodPressureRules.Issue? {
        BloodPressureRules.issue(systolic: systolic, diastolic: diastolic, pulse: pulse,
                                 measuredAt: date ?? now, now: now)
    }

    // MARK: - Rules

    @Test("A normal reading passes; pulse is optional")
    func ordinaryReadingPasses() {
        #expect(issue(120, 80) == nil)
        #expect(issue(120, 80, pulse: 70) == nil)
    }

    @Test("Range bounds are inclusive; beyond them is rejected")
    func rangeBoundaries() {
        #expect(issue(60, 30) == nil)
        #expect(issue(300, 200) == nil)
        #expect(issue(59, 30) == .systolicOutOfRange)
        #expect(issue(301, 80) == .systolicOutOfRange)
        #expect(issue(120, 29) == .diastolicOutOfRange)
        #expect(issue(250, 201) == .diastolicOutOfRange)
        #expect(issue(120, 80, pulse: 29) == .pulseOutOfRange)
        #expect(issue(120, 80, pulse: 221) == .pulseOutOfRange)
        #expect(issue(120, 80, pulse: 30) == nil)
        #expect(issue(120, 80, pulse: 220) == nil)
    }

    @Test("Swapped fields are rejected even when both numbers are in range")
    func invertedPairIsRefused() {
        #expect(issue(80, 120) == .inverted)
        #expect(issue(90, 90) == .inverted)
    }

    @Test("A reading from the future is rejected; now isn't")
    func futureReadingIsRefused() {
        #expect(issue(120, 80, at: now) == nil)
        #expect(issue(120, 80, at: now.addingTimeInterval(60)) == .inFuture)
    }

    // MARK: - Saving

    private func makeLogging() -> (BloodPressureLogging, MockDatabaseService, SpyErrorReporter) {
        let db = MockDatabaseService()
        let errors = SpyErrorReporter()
        let logging = BloodPressureLogging(
            diary: SwiftDataDiaryRepository(store: db), errors: errors, time: FixedTime(now)
        )
        return (logging, db, errors)
    }

    @Test("A valid reading is written as is")
    func validReadingIsWritten() {
        let (logging, db, errors) = makeLogging()

        let saved = logging.save(measuredAt: now, systolic: 135, diastolic: 85, pulse: 72)

        #expect(saved)
        #expect(db.savedBloodPressure?.systolic == 135)
        #expect(db.savedBloodPressure?.diastolic == 85)
        #expect(db.savedBloodPressure?.pulse == 72)
        #expect(errors.reported.isEmpty)
    }

    @Test("An implausible reading isn't written, and the reason goes to ErrorReporting")
    func invalidReadingIsRefusedAndReported() {
        let (logging, db, errors) = makeLogging()

        let saved = logging.save(measuredAt: now, systolic: 80, diastolic: 120, pulse: nil)

        #expect(saved == false)
        #expect(db.savedBloodPressure == nil)
        guard case .invalid(.inverted) = errors.reported.first as? BloodPressureError else {
            Issue.record("expected BloodPressureError.invalid(.inverted), got \(String(describing: errors.reported.first))")
            return
        }
    }

    @Test("The diary screen saves through the same rules")
    func diaryScreenUsesTheSameRules() {
        let db = MockDatabaseService()
        let errors = SpyErrorReporter()
        let vm = DiaryViewModel(dbService: db, errors: errors)

        vm.addBloodPressureReading(measuredAt: Date(), systolic: 1200, diastolic: 80, pulse: nil)

        #expect(db.savedBloodPressure == nil)
        #expect(errors.reported.count == 1)
    }
}
