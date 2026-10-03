//
//  ReviewPromptTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 03.10.2026.
//

import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("Review prompt")
struct ReviewPromptTests {

    // MARK: - Helpers

    /// A prompt over its own defaults suite, isolated from the app's settings.
    private func makePrompt(
        at now: Date = testDate(2026, 10, 1, 9),
        version: String = "1.0"
    ) -> (ReviewPrompt, FixedTime, UserDefaults, String) {
        let suite = "PlekioTests.ReviewPrompt.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let time = FixedTime(now)
        return (ReviewPrompt(defaults: defaults, time: time, appVersion: version), time, defaults, suite)
    }

    /// Opens the app on `days` different days, starting today.
    private func open(_ prompt: ReviewPrompt, on days: Int, advancing time: FixedTime) {
        for day in 0..<days {
            if day > 0 { time.now = addingDays(1, to: time.now) }
            prompt.recordActiveDay()
        }
    }

    // MARK: - Counting

    @Test("Opening the app again the same day counts once")
    func sameDayCountsOnce() {
        let (prompt, time, defaults, suite) = makePrompt()
        defer { defaults.removePersistentDomain(forName: suite) }

        prompt.recordActiveDay()
        time.advance(by: 3 * 3600)
        prompt.recordActiveDay()

        #expect(prompt.activeDays == 1)
    }

    @Test("Days count by the calendar, not by 24 hours")
    func lateNightAndEarlyMorningAreTwoDays() {
        let (prompt, time, defaults, suite) = makePrompt(at: testDate(2026, 10, 1, 23, 50))
        defer { defaults.removePersistentDomain(forName: suite) }

        prompt.recordActiveDay()
        time.advance(by: 20 * 60)
        prompt.recordActiveDay()

        #expect(prompt.activeDays == 2)
    }

    // MARK: - Asking

    @Test("Not due before the third day")
    func notDueEarly() {
        let (prompt, time, defaults, suite) = makePrompt()
        defer { defaults.removePersistentDomain(forName: suite) }

        open(prompt, on: ReviewPrompt.requiredActiveDays - 1, advancing: time)

        #expect(prompt.takeRequestIfDue() == false)
    }

    @Test("Due on the third day, then spent for this version")
    func dueOnceOnTheThirdDay() {
        let (prompt, time, defaults, suite) = makePrompt()
        defer { defaults.removePersistentDomain(forName: suite) }

        open(prompt, on: ReviewPrompt.requiredActiveDays, advancing: time)

        #expect(prompt.takeRequestIfDue())
        #expect(prompt.takeRequestIfDue() == false)
    }

    @Test("A new version may ask again; the count survives the update")
    func newVersionAsksAgain() {
        let (prompt, time, defaults, suite) = makePrompt(version: "1.0")
        defer { defaults.removePersistentDomain(forName: suite) }
        open(prompt, on: ReviewPrompt.requiredActiveDays, advancing: time)
        _ = prompt.takeRequestIfDue()

        let updated = ReviewPrompt(defaults: defaults, time: time, appVersion: "1.1")

        #expect(updated.activeDays == ReviewPrompt.requiredActiveDays)
        #expect(updated.takeRequestIfDue())
    }

    // MARK: - Trigger

    @Test("Only taking a dose is the moment to ask")
    func onlyTakingTriggers() {
        let id = "dose@1"
        let pending: DoseFeedback.Statuses = [id: .pending]

        #expect(DoseFeedback.tookADose(from: pending, to: [id: .taken(at: .now, dispensed: 1)]))
        #expect(DoseFeedback.tookADose(from: pending, to: [id: .skipped(at: .now)]) == false)
        #expect(DoseFeedback.tookADose(from: pending, to: ["other@2": .taken(at: .now, dispensed: 1)]) == false)
    }
}
