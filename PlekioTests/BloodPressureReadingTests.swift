//
//  BloodPressureReadingTests.swift
//  PlekioTests
//
//  The rule the ranges cannot express: systolic above diastolic.
//

import Testing
@testable import Plekio

@Suite("Blood pressure ordering")
struct BloodPressureReadingTests {

    @Test("Нормальний вимір приймається")
    func testOrdinaryReadingIsOrdered() {
        #expect(BloodPressureReading.isOrdered(systolic: 120, diastolic: 80))
    }

    @Test("Перевернута пара відхиляється, хоча обидва числа в діапазоні")
    func testInvertedPairIsRejected() {
        // Exactly the bug: 120 is inside 60...300 and 199 inside 30...200, so
        // checking each range on its own let this through.
        #expect(BloodPressureReading.systolicRange.contains(120))
        #expect(BloodPressureReading.diastolicRange.contains(199))
        #expect(BloodPressureReading.isOrdered(systolic: 120, diastolic: 199) == false)
    }

    @Test("Однакові значення — не вимір")
    func testEqualValuesAreRejected() {
        #expect(BloodPressureReading.isOrdered(systolic: 90, diastolic: 90) == false)
    }

    @Test("Вузький пульсовий тиск приймається")
    func testNarrowPulsePressureIsKept() {
        // Rare but real. A form that refused it would drop the readings that
        // matter most.
        #expect(BloodPressureReading.isOrdered(systolic: 95, diastolic: 90))
    }
}
