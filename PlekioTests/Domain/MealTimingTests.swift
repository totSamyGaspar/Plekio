//
//  MealTimingTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 09.11.2026.
//

import Testing
import Foundation
@testable import Plekio

@Suite("MealTiming")
struct MealTimingTests {

    @Test("A name without meal timing stays as it is")
    func labelWithoutTiming() {
        #expect(MealTiming.label("Iron", nil) == "Iron")
    }

    @Test("A name with meal timing carries its title")
    func labelWithTiming() {
        let label = MealTiming.label("Iron", .emptyStomach)
        #expect(label.contains("Iron"))
        #expect(label.contains(String(localized: MealTiming.emptyStomach.title)))
    }
}
