//
//  MedicationDraftTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 19.11.2026.
//

import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("MedicationDraft validation")
struct MedicationDraftTests {

    // MARK: - Name

    @Test("A name of spaces or line breaks only is not valid", arguments: ["", " ", "   ", "\n", " \t "])
    func blankNameIsInvalid(_ name: String) {
        #expect(!MedicationDraft(name: name).isValid)
    }

    @Test("A name with text in it is valid")
    func nameIsValid() {
        #expect(MedicationDraft(name: "Ibuprofen").isValid)
        #expect(MedicationDraft(name: "  Ibuprofen ").isValid)
    }

    @Test("The saved draft has the name trimmed and everything else as it was")
    func savedDraftIsTrimmed() {
        var draft = MedicationDraft(name: "  Vitamin D3 \n")
        draft.dosage = 2
        draft.stockCount = 60

        let saved = draft.forSaving
        #expect(saved.name == "Vitamin D3")
        #expect(saved.id == draft.id)
        #expect(saved.dosage == 2)
        #expect(saved.stockCount == 60)
    }

    // MARK: - Low stock from the start

    @Test("A threshold below the package size doesn't warn")
    func thresholdBelowStock() {
        #expect(!MedicationDraft(stockCount: 30, lowStockThreshold: 10).isLowFromTheStart)
    }

    @Test("A threshold at or above the package size warns", arguments: [30, 31, 100])
    func thresholdAtOrAboveStock(_ threshold: Int) {
        #expect(MedicationDraft(stockCount: 30, lowStockThreshold: threshold).isLowFromTheStart)
    }
}
