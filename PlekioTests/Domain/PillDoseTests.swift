//
//  PillDoseTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 28.08.2026.
//

import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("PillDose")
struct PillDoseTests {

    // MARK: - Helpers

    private func dose(at time: Date, status: DoseStatus = .pending) -> PillDose {
        PillDose(
            medicationId: UUID(),
            name: "Ibuprofen",
            dosage: 1,
            formSystemImage: "pills.fill",
            time: time,
            period: .morning,
            status: status
        )
    }

    // MARK: - Missed and loggable

    @Test("A missed dose can still be logged")
    func testMissedDoseStaysLoggable() async throws {
        let missed = dose(at: Date().addingTimeInterval(-2 * 3600))

        #expect(missed.isMissed == true)
        #expect(missed.isLoggable == true)
    }

    @Test("A dose within an hour after its time isn't missed and can be logged")
    func testRecentDoseIsNotMissed() async throws {
        let recent = dose(at: Date().addingTimeInterval(-600))

        #expect(recent.isMissed == false)
        #expect(recent.isLoggable == true)
    }

    @Test("A past day's dose can be logged retroactively")
    func testPastDayDoseIsLoggable() async throws {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let time = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: yesterday)!

        #expect(dose(at: time).isLoggable == true)
    }

    @Test("Any dose today can be logged, even before its time")
    func testTodayDoseIsAlwaysLoggable() async throws {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let lateToday = startOfToday.addingTimeInterval(23 * 3600)

        #expect(dose(at: lateToday).isLoggable == true)
    }

    @Test("A future day's dose stays read-only")
    func testFutureDayDoseIsNotLoggable() async throws {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let time = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow)!

        #expect(dose(at: time).isLoggable == false)
    }

    @Test("A logged dose isn't missed")
    func testTakenDoseIsNeverMissed() async throws {
        let taken = dose(at: Date().addingTimeInterval(-5 * 3600), status: .taken(at: Date(), dispensed: 1))

        #expect(taken.isMissed == false)
    }

    // MARK: - Skipped

    // A skip is a decision: it must never decay into "missed" after the grace hour.

    @Test("The stored status reaches the dose whole: taken and skipped never coexist")
    func statusIsOneValue() {
        let taken = dose(at: Date(), status: .taken(at: Date(), dispensed: 1))
        #expect(taken.isTaken && !taken.isSkipped)

        var reopened = taken
        reopened.status = .skipped(at: Date())
        #expect(reopened.isSkipped && !reopened.isTaken)
    }

    @Test("A deliberately skipped dose doesn't become missed")
    func testSkippedDoseIsNeverMissed() async throws {
        var skipped = dose(at: Date().addingTimeInterval(-5 * 3600))
        skipped.status = .skipped(at: Date())

        #expect(skipped.isMissed == false)
        #expect(skipped.isTaken == false)
        // Still loggable: the user can change their mind.
        #expect(skipped.isLoggable == true)
    }

    @Test("The same dose without a skip is missed")
    func testSameDoseWithoutSkipIsMissed() async throws {
        let untouched = dose(at: Date().addingTimeInterval(-5 * 3600))

        #expect(untouched.isMissed == true)
    }
}
