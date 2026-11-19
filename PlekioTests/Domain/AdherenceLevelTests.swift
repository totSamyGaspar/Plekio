//
//  AdherenceLevelTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 19.11.2026.
//

import Testing
@testable import Plekio

@Suite("AdherenceLevel")
struct AdherenceLevelTests {

    @Test("Each average lands on its level, boundaries included", arguments: [
        (100, AdherenceLevel.optimal),
        (90, .optimal),
        (89, .couldBeBetter),
        (70, .couldBeBetter),
        (69, .needsAttention),
        (0, .needsAttention),
    ])
    func level(percent: Int, expected: AdherenceLevel) {
        #expect(AdherenceLevel(percent: percent) == expected)
    }
}
