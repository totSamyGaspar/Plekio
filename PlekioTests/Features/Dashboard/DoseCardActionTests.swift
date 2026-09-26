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
        PillDose(medicationId: UUID(), name: "Medication", dosage: 1, formSystemImage: "pills.fill",
                 time: now.addingTimeInterval(offset), period: .morning, status: status, courseId: courseId)
    }

    // MARK: - Menu

    @Test("An open dose offers log, skip and open course")
    func pendingDoseOffersEverything() {
        #expect(DoseCardAction.menu(for: dose(), at: now) == [.toggle, .skip, .showCourse])
    }

    @Test("A taken dose can only be undone; skip isn't offered")
    func takenDoseOffersUndoOnly() {
        let pill = dose(.taken(at: now, dispensed: 1))
        #expect(DoseCardAction.menu(for: pill, at: now) == [.toggle, .showCourse])
        #expect(DoseCardAction.toggle.systemImage(for: pill) == "arrow.uturn.backward")
    }

    @Test("A skipped dose can be logged but not skipped again")
    func skippedDoseCanBeLogged() {
        #expect(DoseCardAction.menu(for: dose(.skipped(at: now)), at: now) == [.toggle, .showCourse])
    }

    @Test("A future day's dose can't be logged; only the course link remains")
    func futureDayOffersCourseOnly() {
        #expect(DoseCardAction.menu(for: dose(offset: 3 * 86_400), at: now) == [.showCourse])
    }

    @Test("Without a course there is no Open course item")
    func noCourseNoLink() {
        #expect(DoseCardAction.menu(for: dose(courseId: nil), at: now) == [.toggle, .skip])
    }
}
