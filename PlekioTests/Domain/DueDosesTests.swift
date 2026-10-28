//
//  DueDosesTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 22.10.2026.
//

import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("DueDoses")
struct DueDosesTests {

    private let calendar = Calendar.current
    private var day: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 22))! }

    private func at(_ hour: Int, _ minute: Int = 0, dayOffset: Int = 0) -> Date {
        let base = calendar.date(byAdding: .day, value: dayOffset, to: day)!
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base)!
    }

    private func dose(_ name: String, at time: Date, _ status: DoseStatus = .pending) -> PillDose {
        PillDose(medicationId: UUID(), name: name, dosage: 1, form: .pill, time: time, period: .morning, status: status)
    }

    // MARK: - Due

    @Test("The latest slot that has come is due, late ones included")
    func latestPastSlotIsDue() {
        let pills = [dose("A", at: at(8)), dose("B", at: at(14)), dose("C", at: at(20))]

        #expect(DueDoses.due(in: pills, at: at(16))?.time == at(14))
    }

    @Test("A missed slot is due when nothing later has come")
    func missedSlotIsDue() {
        let pills = [dose("A", at: at(8)), dose("C", at: at(20))]

        #expect(DueDoses.due(in: pills, at: at(12))?.time == at(8))
    }

    @Test("A slot within the hour wins over a missed one")
    func upcomingSlotBeatsMissed() {
        let pills = [dose("A", at: at(8)), dose("B", at: at(22, 30))]

        #expect(DueDoses.due(in: pills, at: at(22))?.time == at(22, 30))
    }

    @Test("A slot that has just come wins over one starting within the hour")
    func currentSlotBeatsUpcoming() {
        let pills = [dose("A", at: at(14)), dose("B", at: at(14, 45))]

        #expect(DueDoses.due(in: pills, at: at(14, 10))?.time == at(14))
    }

    @Test("A slot within the hour is due early; one further off is not")
    func upcomingSlotWithinLead() {
        let pills = [dose("A", at: at(8))]

        #expect(DueDoses.due(in: pills, at: at(7, 15))?.time == at(8))
        #expect(DueDoses.due(in: pills, at: at(6, 30)) == nil)
    }

    @Test("Taken and skipped doses are left out of the due slot")
    func onlyOpenDosesAreDue() {
        let pills = [dose("A", at: at(8), .taken(at: at(8), dispensed: nil)), dose("B", at: at(8)), dose("C", at: at(14), .skipped(at: at(14)))]

        let due = DueDoses.due(in: pills, at: at(15))

        #expect(due?.time == at(8))
        #expect(due?.doses.map(\.name) == ["B"])
    }

    @Test("Nothing is due once every dose is logged")
    func nothingDueWhenAllLogged() {
        let pills = [dose("A", at: at(8), .taken(at: at(8), dispensed: nil))]

        #expect(DueDoses.due(in: pills, at: at(9)) == nil)
    }

    // MARK: - Upcoming

    @Test("Next skips a missed slot, which is reported on its own")
    func nextAndMissed() {
        let pills = [dose("A", at: at(8)), dose("B", at: at(14))]

        let upcoming = DueDoses.upcoming(today: pills, tomorrow: [], at: at(10))

        #expect(upcoming.missed?.time == at(8))
        #expect(upcoming.next?.time == at(14))
        #expect(upcoming.tomorrow == nil)
    }

    @Test("Tomorrow's first slot only when nothing is left today")
    func tomorrowWhenDayIsDone() {
        let today = [dose("A", at: at(8), .taken(at: at(8), dispensed: nil))]
        let tomorrow = [dose("A", at: at(8, dayOffset: 1)), dose("B", at: at(20, dayOffset: 1))]

        let upcoming = DueDoses.upcoming(today: today, tomorrow: tomorrow, at: at(21))

        #expect(upcoming.next == nil)
        #expect(upcoming.missed == nil)
        #expect(upcoming.tomorrow?.time == at(8, dayOffset: 1))
    }

    @Test("A slot's doses are grouped and sorted by name")
    func slotsGroupedByTime() {
        let pills = [dose("Zinc", at: at(8)), dose("Aspirin", at: at(8)), dose("B", at: at(20))]

        let slots = DueDoses.openSlots(pills)

        #expect(slots.map(\.time) == [at(8), at(20)])
        #expect(slots.first?.doses.map(\.name) == ["Aspirin", "Zinc"])
    }
}
