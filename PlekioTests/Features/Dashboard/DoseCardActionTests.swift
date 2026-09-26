//
//  DoseCardActionTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 26.09.2026.
//

import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("DoseCardAction")
struct DoseCardActionTests {

    // MARK: - Helpers

    private let now = Date(timeIntervalSince1970: 1_900_000_000)

    private func dose(_ status: DoseStatus = .pending, offset: TimeInterval = -600, courseId: UUID? = UUID()) -> PillDose {
        PillDose(medicationId: UUID(), name: "Лекарство", dosage: 1, formSystemImage: "pills.fill",
                 time: now.addingTimeInterval(offset), period: .morning, status: status, courseId: courseId)
    }

    // MARK: - Menu

    @Test("открытая доза: отметить, пропустить, открыть курс")
    func pendingDoseOffersEverything() {
        #expect(DoseCardAction.menu(for: dose(), at: now) == [.toggle, .skip, .showCourse])
    }

    @Test("принятую дозу можно только отменить, пропуск не предлагается")
    func takenDoseOffersUndoOnly() {
        let pill = dose(.taken(at: now, dispensed: 1))
        #expect(DoseCardAction.menu(for: pill, at: now) == [.toggle, .showCourse])
        #expect(DoseCardAction.toggle.systemImage(for: pill) == "arrow.uturn.backward")
    }

    @Test("пропущенную дозу можно отметить, но не пропустить повторно")
    func skippedDoseCanBeLogged() {
        #expect(DoseCardAction.menu(for: dose(.skipped(at: now)), at: now) == [.toggle, .showCourse])
    }

    @Test("дозу будущего дня нельзя отметить — остаётся только курс")
    func futureDayOffersCourseOnly() {
        #expect(DoseCardAction.menu(for: dose(offset: 3 * 86_400), at: now) == [.showCourse])
    }

    @Test("без курса пункта «Открыть курс» нет")
    func noCourseNoLink() {
        #expect(DoseCardAction.menu(for: dose(courseId: nil), at: now) == [.toggle, .skip])
    }
}
