//
//  DayHeroTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 11.11.2026.
//

import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("DayHero")
struct DayHeroTests {

    // MARK: - Helpers

    private let calendar = Calendar.current
    /// 10 June, 12:00.
    private let now = testDate(2026, 6, 10, 12, 0)

    private func dose(_ name: String, at hour: Int, _ status: DoseStatus = .pending, day: Int = 10) -> PillDose {
        PillDose(medicationId: UUID(), name: name, dosage: 1, form: .pill,
                 time: testDate(2026, 6, day, hour, 0), period: DayPeriod(hour: hour), status: status)
    }

    private func hero(_ pills: [PillDose], on day: Date? = nil) -> DayHero {
        DayHero(pills: pills, selectedDate: day ?? now, now: now, calendar: calendar)
    }

    private let taken = DoseStatus.taken(at: testDate(2026, 6, 10, 9, 0), dispensed: 1)

    // MARK: - Up next

    @Test("Up next is every dose of the earliest open slot")
    func upNextIsTheEarliestSlot() {
        let pills = [dose("A", at: 20), dose("B", at: 14), dose("C", at: 14), dose("D", at: 9, taken)]

        #expect(hero(pills).upNext?.map(\.name).sorted() == ["B", "C"])
        #expect(hero(pills).front?.map(\.name).sorted() == ["B", "C"])
    }

    @Test("A missed dose isn't up next; the next open slot is")
    func missedDoseIsSkipped() {
        // 10:00 is past the hour's grace at 12:00.
        let pills = [dose("Missed", at: 10), dose("Later", at: 18)]

        #expect(hero(pills).upNext?.map(\.name) == ["Later"])
    }

    @Test("Another day has no up next and no card")
    func otherDayHasNoCard() {
        let tomorrow = [dose("A", at: 9, day: 11)]

        let result = hero(tomorrow, on: testDate(2026, 6, 11))
        #expect(result.upNext == nil)
        #expect(result.front == nil)
        #expect(!result.isDayComplete)
    }

    // MARK: - Day complete

    @Test("Once every dose is taken or skipped, the card shows the day's last slot, turned over")
    func completeDayShowsTheLastSlot() {
        let pills = [dose("A", at: 9, taken), dose("B", at: 11, .skipped(at: now))]

        let result = hero(pills)
        #expect(result.isDayComplete)
        #expect(result.upNext == nil)
        #expect(result.front?.map(\.name) == ["B"])
    }

    @Test("A missed dose leaves the day open and hides the card")
    func missedDoseKeepsTheDayOpen() {
        let pills = [dose("A", at: 9, taken), dose("Missed", at: 10)]

        let result = hero(pills)
        #expect(!result.isDayComplete)
        #expect(result.front == nil)
    }

    @Test("An empty day isn't complete")
    func emptyDayIsNotComplete() {
        #expect(!hero([]).isDayComplete)
        #expect(hero([]).front == nil)
    }

    // MARK: - Counts

    @Test("Counts are taken of all, skips not counted as taken")
    func counts() {
        let pills = [dose("A", at: 9, taken), dose("B", at: 11, .skipped(at: now)), dose("C", at: 20)]

        #expect(hero(pills).takenCount == 1)
        #expect(hero(pills).totalCount == 3)
    }
}
