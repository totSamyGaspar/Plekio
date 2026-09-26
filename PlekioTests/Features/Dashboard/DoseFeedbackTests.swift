//
//  DoseFeedbackTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 26.09.2026.
//

import Testing
import SwiftUI
@testable import Plekio

@Suite("DoseFeedback")
struct DoseFeedbackTests {

    // MARK: - Helpers

    private let taken = DoseStatus.taken(at: Date(timeIntervalSince1970: 1_900_000_000), dispensed: 1)
    private let skipped = DoseStatus.skipped(at: Date(timeIntervalSince1970: 1_900_000_000))

    private func statuses(_ values: [DoseStatus]) -> DoseFeedback.Statuses {
        Dictionary(uniqueKeysWithValues: values.enumerated().map { ("dose-\($0.offset)", $0.element) })
    }

    // MARK: - Feedback

    @Test("A logged dose is a success")
    func takingIsSuccess() {
        let feedback = DoseFeedback.feedback(from: statuses([.pending, .pending]), to: statuses([taken, .pending]))
        #expect(feedback == .success)
    }

    @Test("A skip is a warning")
    func skippingIsWarning() {
        #expect(DoseFeedback.feedback(from: statuses([.pending]), to: statuses([skipped])) == .warning)
    }

    @Test("Unlogging gives a light impact")
    func revertingIsLightImpact() {
        #expect(DoseFeedback.feedback(from: statuses([taken]), to: statuses([.pending])) == .impact(weight: .light))
    }

    @Test("If anything was taken as well, success wins")
    func takingWinsOverOtherChanges() {
        let feedback = DoseFeedback.feedback(from: statuses([.pending, taken]), to: statuses([taken, .pending]))
        #expect(feedback == .success)
    }

    @Test("A different set of doses (another day) gives no feedback")
    func differentDosesAreSilent() {
        let other: DoseFeedback.Statuses = ["another-day": taken]
        #expect(DoseFeedback.feedback(from: statuses([.pending]), to: other) == nil)
    }

    @Test("No change, no feedback")
    func noChangeIsSilent() {
        #expect(DoseFeedback.feedback(from: statuses([taken]), to: statuses([taken])) == nil)
    }
}
