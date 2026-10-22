//
//  WidgetLinkTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 21.10.2026.
//

import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("WidgetLink")
struct WidgetLinkTests {

    private let slot = testDate(2026, 10, 21, 8, 30)

    private func dose(_ status: WidgetSnapshot.Status) -> WidgetSnapshot.Dose {
        WidgetSnapshot.Dose(medicationId: UUID(), name: "Dose", dosage: 1, form: .pill, status: status)
    }

    @Test("A link reads back as itself, the slot to the exact second")
    func roundTrips() {
        let ids = [UUID(), UUID()]
        let links: [WidgetLink] = [.today, .diaryCheckIn, .bloodPressureEntry, .dose(slot: slot, medicationIds: ids)]
        for link in links {
            #expect(WidgetLink(url: link.url) == link)
        }
        #expect(WidgetLink(url: WidgetLink.dose(slot: slot.addingTimeInterval(0.5), medicationIds: ids).url)
                == .dose(slot: slot.addingTimeInterval(0.5), medicationIds: ids))
    }

    @Test("Other apps' URLs, unknown hosts and empty dose links are ignored")
    func rejectsWhatItDidNotBuild() throws {
        #expect(WidgetLink(url: try #require(URL(string: "https://plekio.app/today"))) == nil)
        #expect(WidgetLink(url: try #require(URL(string: "plekio://settings"))) == nil)
        #expect(WidgetLink(url: try #require(URL(string: "plekio://dose?slot=1800000000"))) == nil)
        #expect(WidgetLink(url: try #require(URL(string: "plekio://dose?ids=\(UUID().uuidString)"))) == nil)
    }

    @Test("A malformed id is dropped, the rest still open")
    func dropsMalformedIds() throws {
        let id = UUID()
        let url = try #require(URL(string: "plekio://dose?slot=1800000000&ids=nope,\(id.uuidString)"))
        #expect(WidgetLink(url: url) == .dose(slot: Date(timeIntervalSince1970: 1_800_000_000), medicationIds: [id]))
    }

    @Test("A slot opens its open doses, and Today once all are logged")
    func slotLinksToItsOpenDoses() {
        let open = dose(.pending)
        let partly = WidgetSnapshot.Slot(time: slot, period: .morning, doses: [dose(.taken), open, dose(.skipped)])
        let done = WidgetSnapshot.Slot(time: slot, period: .morning, doses: [dose(.taken)])

        #expect(partly.openLink == .dose(slot: slot, medicationIds: [open.medicationId]))
        #expect(done.openLink == .today)
    }
}
