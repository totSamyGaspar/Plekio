//
//  WidgetSnapshotTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 21.10.2026.
//

import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("WidgetSnapshot reading")
struct WidgetSnapshotTests {

    // MARK: - Helpers

    private let calendar = Calendar.current
    private let grace: TimeInterval = 3600

    private func dose(_ name: String, _ status: WidgetSnapshot.Status = .pending) -> WidgetSnapshot.Dose {
        WidgetSnapshot.Dose(medicationId: UUID(), name: name, dosage: 1, form: .pill, status: status)
    }

    private func slot(_ time: Date, _ doses: WidgetSnapshot.Dose...) -> WidgetSnapshot.Slot {
        WidgetSnapshot.Slot(time: time, period: .morning, doses: doses)
    }

    /// 08:00 taken, 14:00 pending, 20:00 pending, tomorrow 08:00 pending.
    private func dayOfThree(eveningStatus: WidgetSnapshot.Status = .pending) -> WidgetSnapshot {
        WidgetSnapshot(
            generatedAt: testDate(2026, 10, 21, 7),
            missedGrace: grace,
            slots: [
                slot(testDate(2026, 10, 21, 8), dose("Sertraline", .taken)),
                slot(testDate(2026, 10, 21, 14), dose("Folic Acid")),
                slot(testDate(2026, 10, 21, 20), dose("Magnesium", eveningStatus), dose("Omega-3", eveningStatus)),
                slot(testDate(2026, 10, 22, 8), dose("Sertraline"))
            ],
            streakDays: 3,
            lowStock: []
        )
    }

    // MARK: - Day

    @Test("Progress counts only today's doses; a skip is in the total, not the taken")
    func progressCountsToday() {
        var snapshot = dayOfThree()
        snapshot.slots[1].doses[0].status = .skipped
        let progress = snapshot.progress(onDayOf: testDate(2026, 10, 21, 12), calendar: calendar)
        #expect(progress.taken == 1)
        #expect(progress.total == 4)
    }

    @Test("The day is complete only once every dose is taken or skipped")
    func dayCompleteNeedsEverySettled() {
        let noon = testDate(2026, 10, 21, 12)
        #expect(!dayOfThree().isDayComplete(at: noon, calendar: calendar))

        var settled = dayOfThree(eveningStatus: .taken)
        settled.slots[1].doses[0].status = .skipped
        #expect(settled.isDayComplete(at: noon, calendar: calendar))
    }

    @Test("A day with nothing scheduled is not complete")
    func emptyDayIsNotComplete() {
        let snapshot = WidgetSnapshot.empty(at: testDate(2026, 10, 21, 9), missedGrace: grace)
        #expect(!snapshot.isDayComplete(at: testDate(2026, 10, 21, 9), calendar: calendar))
    }

    // MARK: - Up next

    @Test("Up next is the earliest slot with an open dose, skipping settled ones")
    func upNextSkipsSettledSlots() {
        let next = dayOfThree().upNext(at: testDate(2026, 10, 21, 7), calendar: calendar)
        #expect(next?.time == testDate(2026, 10, 21, 14))
    }

    @Test("A slot past its grace leaves up next, as on the hero card")
    func missedSlotLeavesUpNext() {
        let next = dayOfThree().upNext(at: testDate(2026, 10, 21, 15, 30), calendar: calendar)
        #expect(next?.time == testDate(2026, 10, 21, 20))
    }

    @Test("A slot within its grace is still up next")
    func lateSlotWithinGraceStaysUpNext() {
        let next = dayOfThree().upNext(at: testDate(2026, 10, 21, 14, 59), calendar: calendar)
        #expect(next?.time == testDate(2026, 10, 21, 14))
    }

    @Test("Up next never reaches into tomorrow")
    func upNextStaysOnToday() {
        let snapshot = dayOfThree(eveningStatus: .taken)
        #expect(snapshot.upNext(at: testDate(2026, 10, 21, 15, 30), calendar: calendar) == nil)
        #expect(snapshot.firstSlot(afterDayOf: testDate(2026, 10, 21, 15, 30), calendar: calendar)?.time
                == testDate(2026, 10, 22, 8))
    }

    // MARK: - Missed

    @Test("Missed lists today's overdue slots, most recent first")
    func missedIsLatestFirst() {
        var snapshot = dayOfThree()
        snapshot.slots[0].doses[0].status = .pending
        let missed = snapshot.missed(at: testDate(2026, 10, 21, 16), calendar: calendar)
        #expect(missed.map(\.time) == [testDate(2026, 10, 21, 14), testDate(2026, 10, 21, 8)])
    }

    @Test("A skipped or taken dose is never missed")
    func settledDoseIsNotMissed() {
        let snapshot = dayOfThree()
        let morning = snapshot.slots[0]
        #expect(!snapshot.isMissed(morning.doses[0], in: morning, at: testDate(2026, 10, 21, 23)))
    }

    // MARK: - Logging

    @Test("Today's slots can be logged, even later ones; tomorrow's can't")
    func onlyTodayCanBeLogged() {
        let snapshot = dayOfThree()
        let now = testDate(2026, 10, 21, 9)
        #expect(snapshot.canLog(snapshot.slots[2], at: now, calendar: calendar))
        #expect(!snapshot.canLog(snapshot.slots[3], at: now, calendar: calendar))
    }

    // MARK: - Timeline

    @Test("Change dates are slots, grace ends and midnights after now, in order")
    func changeDatesCoverEveryVisibleChange() {
        let snapshot = WidgetSnapshot(
            generatedAt: testDate(2026, 10, 21, 7),
            missedGrace: grace,
            slots: [slot(testDate(2026, 10, 21, 8), dose("Sertraline"))],
            streakDays: 0,
            lowStock: []
        )
        let dates = snapshot.changeDates(after: testDate(2026, 10, 21, 7), calendar: calendar)
        #expect(dates == [
            testDate(2026, 10, 21, 8),
            testDate(2026, 10, 21, 9).addingTimeInterval(1),
            testDate(2026, 10, 22),
            testDate(2026, 10, 23)
        ])
    }

    @Test("Change dates drop anything already past")
    func changeDatesSkipThePast() {
        let dates = dayOfThree().changeDates(after: testDate(2026, 10, 21, 16), calendar: calendar)
        #expect(dates.allSatisfy { $0 > testDate(2026, 10, 21, 16) })
        #expect(dates.first == testDate(2026, 10, 21, 20))
    }
}
