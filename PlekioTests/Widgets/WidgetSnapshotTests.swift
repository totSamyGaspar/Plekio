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

    @Test("The snapshot covers the day it was built and the next, not the day after")
    func coversTwoDays() {
        let snapshot = dayOfThree()
        #expect(snapshot.covers(testDate(2026, 10, 21, 0), calendar: calendar))
        #expect(snapshot.covers(testDate(2026, 10, 22, 23, 59), calendar: calendar))
        #expect(!snapshot.covers(testDate(2026, 10, 23), calendar: calendar))
        #expect(!snapshot.covers(testDate(2026, 10, 20, 23), calendar: calendar))
    }

    // MARK: - Diary

    @Test("The check-in shows on its own day only: past midnight it's gone")
    func diaryEntryIsForItsDay() {
        var snapshot = dayOfThree()
        snapshot.diary = WidgetSnapshot.DiaryDay(
            checkInDate: testDate(2026, 10, 21, 9), mood: .good, isQuickLog: true,
            energyLevel: 4, sleepHours: 7.5, waterGlasses: 6
        )

        #expect(snapshot.diaryEntry(onDayOf: testDate(2026, 10, 21, 23), calendar: calendar)?.mood == .good)
        #expect(snapshot.diaryEntry(onDayOf: testDate(2026, 10, 22, 0, 1), calendar: calendar) == nil)
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

    @Test("Change dates are slots, grace ends, midnights and hero hours after now, in order")
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
            testDate(2026, 10, 21, 12),
            testDate(2026, 10, 21, 18),
            testDate(2026, 10, 22),
            testDate(2026, 10, 22, 5),
            testDate(2026, 10, 22, 12),
            testDate(2026, 10, 22, 18),
            testDate(2026, 10, 23)
        ])
    }

    // MARK: - Edge cases

    // The scheme pins TZ=Europe/Berlin, where clocks go back at 03:00 on 25 October
    // 2026: that day has 25 hours.

    @Test("Midnights stay on the real start of day across the clock change")
    func midnightsAcrossClockChange() {
        let snapshot = WidgetSnapshot(
            generatedAt: testDate(2026, 10, 24, 20),
            missedGrace: grace,
            slots: [slot(testDate(2026, 10, 25, 8), dose("Sertraline"))],
            streakDays: 0,
            lowStock: []
        )
        let dates = snapshot.changeDates(after: testDate(2026, 10, 24, 20), calendar: calendar)

        #expect(dates.contains(testDate(2026, 10, 25)))
        #expect(dates.contains(testDate(2026, 10, 26)))
        // The two midnights are 25 hours apart, not 24: the day is counted, not the hours.
        #expect(testDate(2026, 10, 26).timeIntervalSince(testDate(2026, 10, 25)) == 25 * 3600)
    }

    @Test("The snapshot covers both days in full when one of them has 25 hours")
    func coverageAcrossClockChange() {
        let snapshot = WidgetSnapshot.empty(at: testDate(2026, 10, 25, 10), missedGrace: grace)

        #expect(snapshot.covers(testDate(2026, 10, 25, 0), calendar: calendar))
        #expect(snapshot.covers(testDate(2026, 10, 26, 23, 30), calendar: calendar))
        #expect(!snapshot.covers(testDate(2026, 10, 27), calendar: calendar))
    }

    @Test("A dose turns missed one second after its grace ends, not at it")
    func graceBoundary() {
        let snapshot = dayOfThree()
        let slotTime = testDate(2026, 10, 21, 14)

        #expect(snapshot.upNext(at: slotTime, calendar: calendar)?.time == slotTime)
        #expect(snapshot.upNext(at: slotTime.addingTimeInterval(grace), calendar: calendar)?.time == slotTime)
        #expect(snapshot.missed(at: slotTime.addingTimeInterval(grace + 1), calendar: calendar).first?.time == slotTime)
        // The timeline's entry for that moment is the one that shows it.
        #expect(snapshot.changeDates(after: slotTime, calendar: calendar).contains(slotTime.addingTimeInterval(grace + 1)))
    }

    @Test("Days are read in the device's time zone: after a flight east, a late dose is tomorrow's")
    func daysFollowTheTimeZone() throws {
        var tbilisi = Calendar(identifier: .gregorian)
        tbilisi.timeZone = try #require(TimeZone(identifier: "Asia/Tbilisi"))
        // 23:30 in Berlin is 01:30 the next day in Tbilisi.
        let late = testDate(2026, 10, 21, 23, 30)
        let snapshot = WidgetSnapshot(
            generatedAt: testDate(2026, 10, 21, 7),
            missedGrace: grace,
            slots: [slot(late, dose("Magnesium"))],
            streakDays: 0,
            lowStock: []
        )
        let nextMorningThere = late.addingTimeInterval(8 * 3600)

        #expect(snapshot.slotsOnDay(of: nextMorningThere, calendar: tbilisi).map(\.time) == [late])
        #expect(snapshot.slotsOnDay(of: late, calendar: calendar).map(\.time) == [late])
    }

    @Test("Change dates drop anything already past")
    func changeDatesSkipThePast() {
        let dates = dayOfThree().changeDates(after: testDate(2026, 10, 21, 16), calendar: calendar)
        #expect(dates.allSatisfy { $0 > testDate(2026, 10, 21, 16) })
        #expect(dates.first == testDate(2026, 10, 21, 20))
    }
}
