//
//  DoseBadgeTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 26.09.2026.
//

import Testing
import Foundation
@testable import Plekio

@Suite("DoseBadge")
struct DoseBadgeTests {

    // MARK: - Helpers

    private let calendar = Calendar.current

    private func date(_ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2030, month: 6, day: 10, hour: hour))!
    }

    private func dose(at hour: Int, _ status: DoseStatus = .pending) -> PillDose {
        PillDose(medicationId: UUID(), name: "Лекарство", dosage: 1, formSystemImage: "pills.fill",
                 time: date(hour), period: DayPeriod(hour: hour), status: status)
    }

    // MARK: - Counting

    @Test("считаются только открытые дозы, время которых пришло")
    func countsOnlyOpenDueDoses() {
        let pills = [
            dose(at: 8),
            dose(at: 9, .taken(at: date(9), dispensed: 1)),
            dose(at: 10, .skipped(at: date(10))),
            dose(at: 11),
            dose(at: 20)
        ]

        #expect(DoseBadge.count(of: pills, at: date(12)) == 2)
    }

    @Test("доза в момент своего времени уже считается")
    func doseCountsAtItsOwnTime() {
        #expect(DoseBadge.count(of: [dose(at: 9)], at: date(9)) == 1)
    }

    @Test("без доз — ноль")
    func emptyIsZero() {
        #expect(DoseBadge.count(of: [], at: date(12)) == 0)
    }
}
