//
//  LocalTimeTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 09.11.2026.
//

import Testing
import Foundation
@testable import Plekio

@Suite("LocalDay and LocalSlot")
struct LocalTimeTests {

    // MARK: - Helpers

    private func calendar(_ identifier: String, _ system: Calendar.Identifier = .gregorian) -> Calendar {
        var calendar = Calendar(identifier: system)
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    private let tbilisi = "Asia/Tbilisi"
    private let berlin = "Europe/Berlin"

    /// A moment given in UTC.
    private func utc(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0, year: Int = 2030) -> Date {
        LocalDay.utc.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    // MARK: - LocalDay

    @Test("One moment near midnight is a different local day in different zones")
    func dayDependsOnTheZone() {
        let moment = utc(6, 10, 21, 30)

        #expect(LocalDay(moment, in: calendar(tbilisi)) == LocalDay(year: 2030, month: 6, day: 11))
        #expect(LocalDay(moment, in: calendar(berlin)) == LocalDay(year: 2030, month: 6, day: 10))
    }

    @Test("A day starts at its local midnight")
    func dayStartsAtLocalMidnight() {
        let day = LocalDay(year: 2030, month: 6, day: 10)

        #expect(day.start(in: calendar(tbilisi)) == utc(6, 9, 20))
        #expect(day.start(in: calendar(berlin)) == utc(6, 9, 22))
        #expect(LocalDay(day.start(in: calendar(tbilisi)), in: calendar(tbilisi)) == day)
    }

    @Test("Days add across months, years and a leap day")
    func addingDays() {
        #expect(LocalDay(year: 2030, month: 12, day: 31).adding(days: 1) == LocalDay(year: 2031, month: 1, day: 1))
        #expect(LocalDay(year: 2028, month: 3, day: 1).adding(days: -1) == LocalDay(year: 2028, month: 2, day: 29))
    }

    /// 31 March 2030: Berlin's day is 23 hours long.
    @Test("Days between count calendar days, even across a clock change")
    func daysAcrossAClockChange() {
        let before = LocalDay(year: 2030, month: 3, day: 30)
        let after = LocalDay(year: 2030, month: 4, day: 1)

        #expect(before.days(to: after) == 2)
        #expect(after.days(to: before) == -2)
        #expect(after.start(in: calendar(berlin)).timeIntervalSince(before.start(in: calendar(berlin))) == 47 * 3600)
    }

    @Test("Days order by date")
    func daysOrder() {
        #expect(LocalDay(year: 2030, month: 6, day: 30) < LocalDay(year: 2030, month: 7, day: 1))
        #expect(LocalDay(year: 2029, month: 12, day: 31) < LocalDay(year: 2030, month: 1, day: 1))
    }

    @Test("The stored form is the day's UTC midnight, whatever the device's zone")
    func dayStorage() {
        let day = LocalDay(year: 2030, month: 6, day: 10)

        #expect(day.stored == utc(6, 10, 0))
        #expect(LocalDay(stored: day.stored) == day)
    }

    @Test("A non-Gregorian calendar still gives Gregorian days")
    func nonGregorianCalendar() {
        let buddhist = calendar(tbilisi, .buddhist)

        #expect(LocalDay(utc(6, 10, 12), in: buddhist) == LocalDay(year: 2030, month: 6, day: 10))
    }

    // MARK: - LocalSlot

    @Test("A slot is the local day and time of a moment")
    func slotFromMoment() {
        let slot = LocalSlot(utc(6, 10, 4), in: calendar(tbilisi))

        #expect(slot == LocalSlot(day: LocalDay(year: 2030, month: 6, day: 10), minuteOfDay: 8 * 60))
    }

    // A dose logged at 09:00:45 is still the 09:00 dose.
    @Test("A slot ignores seconds but not minutes or days")
    func slotIgnoresSeconds() {
        let nine = LocalSlot(utc(6, 10, 9), in: calendar(tbilisi))

        #expect(LocalSlot(utc(6, 10, 9).addingTimeInterval(45), in: calendar(tbilisi)) == nine)
        #expect(LocalSlot(utc(6, 10, 9, 1), in: calendar(tbilisi)) != nine)
        #expect(LocalSlot(utc(6, 11, 9), in: calendar(tbilisi)) != nine)
    }

    @Test("The same slot is 08:00 wherever it's read")
    func slotFollowsLocalTime() {
        let slot = LocalSlot(day: LocalDay(year: 2030, month: 6, day: 10), minuteOfDay: 8 * 60)

        #expect(slot.date(in: calendar(tbilisi)) == utc(6, 10, 4))
        #expect(slot.date(in: calendar(berlin)) == utc(6, 10, 6))
    }

    /// 31 March 2030: Berlin skips 02:00–03:00.
    @Test("A slot the clock change skips moves to the next time that exists")
    func skippedSlot() throws {
        let local = calendar(berlin)
        let slot = LocalSlot(day: LocalDay(year: 2030, month: 3, day: 31), minuteOfDay: 2 * 60 + 30)

        let date = try #require(slot.date(in: local))
        #expect(local.component(.hour, from: date) == 3)
        #expect(LocalDay(date, in: local) == slot.day)
    }

    /// 27 October 2030: Berlin goes through 02:00–03:00 twice.
    @Test("A slot the clock change repeats is its first occurrence")
    func repeatedSlot() throws {
        let slot = LocalSlot(day: LocalDay(year: 2030, month: 10, day: 27), minuteOfDay: 2 * 60 + 30)

        // 02:30 summer time is 00:30 UTC; the repeat, in winter time, would be 01:30.
        #expect(try #require(slot.date(in: calendar(berlin))) == utc(10, 27, 0, 30))
    }

    @Test("Slots order by day, then time")
    func slotsOrder() {
        let day = LocalDay(year: 2030, month: 6, day: 10)

        #expect(LocalSlot(day: day, minuteOfDay: 20 * 60) < LocalSlot(day: day.adding(days: 1), minuteOfDay: 8 * 60))
        #expect(LocalSlot(day: day, minuteOfDay: 8 * 60) < LocalSlot(day: day, minuteOfDay: 9 * 60))
    }

    @Test("The stored form is the slot's day and time in UTC")
    func slotStorage() {
        let slot = LocalSlot(day: LocalDay(year: 2030, month: 6, day: 10), minuteOfDay: 20 * 60 + 30)

        #expect(slot.stored == utc(6, 10, 20, 30))
        #expect(LocalSlot(stored: slot.stored) == slot)
    }
}
