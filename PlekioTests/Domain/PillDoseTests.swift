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
            name: "Ибупрофен",
            dosage: 1,
            formSystemImage: "pills.fill",
            time: time,
            period: .morning,
            status: status
        )
    }

    // MARK: - Missed and loggable

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
        let taken = dose(at: Date().addingTimeInterval(-5 * 3600), status: .taken(at: Date(), dispensed: 1))

        #expect(taken.isMissed == false)
    }

    // MARK: - Skipped

    // A skip is a decision: it must never decay into "missed" after the grace hour.

    @Test("статус из базы доходит до дозы целиком: отметка и пропуск не бывают одновременно")
    func statusIsOneValue() {
        let taken = dose(at: Date(), status: .taken(at: Date(), dispensed: 1))
        #expect(taken.isTaken && !taken.isSkipped)

        var reopened = taken
        reopened.status = .skipped(at: Date())
        #expect(reopened.isSkipped && !reopened.isTaken)
    }

    @Test("пропущенная намеренно доза не становится просроченной")
    func testSkippedDoseIsNeverMissed() async throws {
        var skipped = dose(at: Date().addingTimeInterval(-5 * 3600))
        skipped.status = .skipped(at: Date())

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
