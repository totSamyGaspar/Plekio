//
//  PillDoseTests.swift
//  PillFlowTests
//
//  Regression tests for PillDose.isLoggable — the rule for which dose can be
//  logged at all. The window used to close an hour after the scheduled time, so
//  a dose entered later was lost for good and adherence stats read too low.
//  These tests pin down the new behaviour.
//

import Testing
import Foundation
@testable import PillFlow

@MainActor
@Suite("PillDose")
struct PillDoseTests {

    private func dose(at time: Date, isTaken: Bool = false) -> PillDose {
        PillDose(
            medicationId: UUID(),
            name: "Ибупрофен",
            dosage: 1,
            formSystemImage: "pills.fill",
            time: time,
            period: .morning,
            isTaken: isTaken
        )
    }

    @Test("просроченную дозу всё ещё можно отметить")
    func testMissedDoseStaysLoggable() async throws {
        let missed = dose(at: Date().addingTimeInterval(-2 * 3600))

        #expect(missed.isMissed == true)
        #expect(missed.isLoggable == true)
    }

    @Test("доза в пределах часа после срока: просроченной не считается, отмечается")
    func testRecentDoseIsNotMissed() async throws {
        let recent = dose(at: Date().addingTimeInterval(-600))

        #expect(recent.isMissed == false)
        #expect(recent.isLoggable == true)
    }

    @Test("доза прошедшего дня отмечается задним числом")
    func testPastDayDoseIsLoggable() async throws {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let time = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: yesterday)!

        #expect(dose(at: time).isLoggable == true)
    }

    @Test("любая сегодняшняя доза отмечается, даже если время ещё не наступило")
    func testTodayDoseIsAlwaysLoggable() async throws {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let lateToday = startOfToday.addingTimeInterval(23 * 3600)

        #expect(dose(at: lateToday).isLoggable == true)
    }

    @Test("доза будущего дня остаётся read-only")
    func testFutureDayDoseIsNotLoggable() async throws {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let time = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow)!

        #expect(dose(at: time).isLoggable == false)
    }

    @Test("отмеченная доза просроченной не считается")
    func testTakenDoseIsNeverMissed() async throws {
        let taken = dose(at: Date().addingTimeInterval(-5 * 3600), isTaken: true)

        #expect(taken.isMissed == false)
    }

    // MARK: - Skipped

    // A skip is a decision, so it must not decay into "missed" an hour later.
    // While skipping was merely the absence of a log there was nothing to tell
    // the two apart, and a declined dose eventually showed a MISSED badge.

    @Test("пропущенная намеренно доза не становится просроченной")
    func testSkippedDoseIsNeverMissed() async throws {
        var skipped = dose(at: Date().addingTimeInterval(-5 * 3600))
        skipped.isSkipped = true

        #expect(skipped.isMissed == false)
        #expect(skipped.isTaken == false)
        // Still loggable: the user can change their mind.
        #expect(skipped.isLoggable == true)
    }

    @Test("та же доза без отметки о пропуске просрочена")
    func testSameDoseWithoutSkipIsMissed() async throws {
        let untouched = dose(at: Date().addingTimeInterval(-5 * 3600))

        #expect(untouched.isMissed == true)
    }
}
