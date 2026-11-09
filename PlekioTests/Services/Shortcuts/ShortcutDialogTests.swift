//
//  ShortcutDialogTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 28.10.2026.
//

import Testing
import Foundation
@testable import Plekio

/// Checked by content, not wording, so it holds in any test locale.
@MainActor
@Suite("ShortcutDialog")
struct ShortcutDialogTests {

    private let time = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 8))!

    private var slot: DueDoses.Slot {
        DueDoses.Slot(time: time, doses: [
            PillDose(medicationId: UUID(), name: "Sertraline", dosage: 1, form: .pill, time: time, period: .morning)
        ])
    }

    @Test("Names are said when Plekio isn't locked")
    func namesWithoutLock() {
        #expect(String(localized: ShortcutDialog.logged(slot, hidesDetails: false)).contains("Sertraline"))
        #expect(ShortcutDialog.upcoming(.init(next: slot), hidesDetails: false).contains("Sertraline"))
    }

    @Test("With the lock on, no medication names")
    func noNamesWithLock() {
        #expect(!String(localized: ShortcutDialog.logged(slot, hidesDetails: true)).contains("Sertraline"))
        #expect(!String(localized: ShortcutDialog.skipped(slot, hidesDetails: true)).contains("Sertraline"))
        #expect(!ShortcutDialog.upcoming(.init(next: slot, missed: slot), hidesDetails: true).contains("Sertraline"))
    }

    @Test("With the lock on, no reading")
    func noReadingWithLock() {
        #expect(String(localized: ShortcutDialog.readingSaved(systolic: 128, diastolic: 84, hidesDetails: false)).contains("128/84"))
        #expect(!String(localized: ShortcutDialog.readingSaved(systolic: 128, diastolic: 84, hidesDetails: true)).contains("128"))
    }

    @Test("Doses still to take say when to take them relative to food; logged ones don't")
    func mealTimingOnlyForUpcoming() {
        var dose = slot.doses[0]
        dose.mealTiming = .emptyStomach
        let withMeal = DueDoses.Slot(time: time, doses: [dose])
        let title = String(localized: MealTiming.emptyStomach.title)

        #expect(ShortcutDialog.upcoming(.init(next: withMeal), hidesDetails: false).contains(title))
        #expect(!String(localized: ShortcutDialog.logged(withMeal, hidesDetails: false)).contains(title))
        #expect(!ShortcutDialog.upcoming(.init(next: withMeal), hidesDetails: true).contains(title))
    }
}
