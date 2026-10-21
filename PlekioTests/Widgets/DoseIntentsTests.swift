//
//  DoseIntentsTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 21.10.2026.
//

import Testing
import Foundation
@testable import Plekio

/// The buttons carry a slot back to the app; it must find the same doses there.
@MainActor
@Suite("Widget dose intents")
struct DoseIntentsTests {

    // MARK: - Helpers

    private let time = testDate(2026, 10, 21, 8)

    private func dose(_ status: WidgetSnapshot.Status) -> WidgetSnapshot.Dose {
        WidgetSnapshot.Dose(medicationId: UUID(), name: "Dose", dosage: 1, form: .pill, status: status)
    }

    // MARK: - Tests

    @Test("An intent gives back the exact slot and medications it was built with")
    func intentRoundTripsSlotAndIds() {
        let ids = [UUID(), UUID()]
        let take = TakeDosesIntent(slot: time, medicationIds: ids)
        let skip = SkipDosesIntent(slot: time, medicationIds: ids)

        #expect(take.ids == ids)
        // openDoses(medicationIds:at:) matches within a second; the round trip is exact.
        #expect(take.slot == time)
        #expect(skip.ids == ids)
        #expect(skip.slot == time)
    }

    @Test("A slot's buttons send only its open doses, never taken or skipped ones")
    func slotButtonsSendOpenDoses() {
        let open = dose(.pending)
        let slot = WidgetSnapshot.Slot(time: time, period: .morning, doses: [dose(.taken), open, dose(.skipped)])

        #expect(slot.takeOpenDoses.ids == [open.medicationId])
        #expect(slot.skipOpenDoses.ids == [open.medicationId])
        #expect(slot.takeOpenDoses.slot == time)
    }

    @Test("A dose's own button sends just that dose")
    func doseButtonSendsOneDose() {
        let open = dose(.pending)
        let slot = WidgetSnapshot.Slot(time: time, period: .morning, doses: [dose(.pending), open])

        #expect(slot.take(open).ids == [open.medicationId])
    }

    @Test("A dose's check carries just that dose and its slot")
    func toggleCarriesOneDose() {
        let open = dose(.pending)
        let done = dose(.taken)
        let slot = WidgetSnapshot.Slot(time: time, period: .morning, doses: [done, open])

        #expect(slot.toggle(open).ids == [open.medicationId])
        #expect(slot.toggle(open).slot == time)
        // An open dose's check takes it; a taken one's takes it back.
        #expect(slot.toggle(open).taken)
        #expect(!slot.toggle(done).taken)
    }

    @Test("A malformed id is dropped instead of failing the whole button")
    func malformedIdIsDropped() {
        let id = UUID()
        var intent = TakeDosesIntent(slot: time, medicationIds: [id])
        intent.medicationIds.append("not-a-uuid")

        #expect(intent.ids == [id])
    }
}
