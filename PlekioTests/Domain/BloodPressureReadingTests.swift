//
//  BloodPressureReadingTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 24.09.2026.
//

import Testing
@testable import Plekio

// MARK: - BloodPressureReadingTests

@Suite("Blood pressure ordering")
struct BloodPressureReadingTests {

    @Test("A normal reading is accepted")
    func testOrdinaryReadingIsOrdered() {
        #expect(BloodPressureReading.isOrdered(systolic: 120, diastolic: 80))
    }

    @Test("An inverted pair is rejected even though both numbers are in range")
    func testInvertedPairIsRejected() {
        // Each value is within its own range; only the pair check rejects it.
        #expect(BloodPressureReading.systolicRange.contains(120))
        #expect(BloodPressureReading.diastolicRange.contains(199))
        #expect(BloodPressureReading.isOrdered(systolic: 120, diastolic: 199) == false)
    }

    @Test("Equal values are not a reading")
    func testEqualValuesAreRejected() {
        #expect(BloodPressureReading.isOrdered(systolic: 90, diastolic: 90) == false)
    }

    @Test("A narrow pulse pressure is accepted")
    func testNarrowPulsePressureIsKept() {
        // Rare but real, and clinically important; must not be refused.
        #expect(BloodPressureReading.isOrdered(systolic: 95, diastolic: 90))
    }
}
