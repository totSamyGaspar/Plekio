//
//  StreakRulesTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 21.10.2026.
//

import Testing
import Foundation
@testable import Plekio

/// The streak's behaviour is covered through StatisticsViewModelTests; these pin
/// the pieces the widget reads directly.
@MainActor
@Suite("StreakRules")
struct StreakRulesTests {

    private let today = testDate(2026, 10, 21)

    private func pill(taken: Bool) -> PillDose {
        PillDose(medicationId: UUID(), name: "Dose", dosage: 1, form: .pill, time: today, period: .morning,
                 status: taken ? .taken(at: today, dispensed: 1) : .pending)
    }

    @Test("The history covers today and the lookback before it, newest first")
    func daysCoverLookback() {
        let days = StreakRules.days(endingAt: today, calendar: .current)
        #expect(days.count == StreakRules.lookbackDays + 1)
        #expect(days.first == today)
        #expect(days.last == addingDays(-StreakRules.lookbackDays, to: today))
    }

    @Test("Adherence is nil for an empty day and the logged share otherwise")
    func adherence() {
        #expect(StreakRules.adherence(of: []) == nil)
        #expect(StreakRules.adherence(of: [pill(taken: true), pill(taken: false)]) == 0.5)
    }

    @Test("An unfinished today doesn't break yesterday's streak")
    func unfinishedTodayKeepsStreak() {
        let yesterday = addingDays(-1, to: today)
        let streak = StreakRules.streak(
            pillsByDay: [today: [pill(taken: false)], yesterday: [pill(taken: true)]],
            today: today,
            calendar: .current
        )
        #expect(streak == 1)
    }
}
