//
//  TestEnvironmentTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Testing
import Foundation

// MARK: - TestEnvironmentTests

@Suite("Test environment")
struct TestEnvironmentTests {

    @Test("The tests' time zone and region are pinned in the scheme")
    func timeZoneAndRegionArePinned() {
        #expect(TimeZone.current.identifier == "Europe/Berlin",
                "Run tests with the Plekio scheme: its Test action sets TZ=Europe/Berlin")
        // uk_UA starts the week on Monday, which the weekly stats rely on.
        #expect(Calendar.current.firstWeekday == 2,
                "Run tests with the Plekio scheme: its Test action sets -AppleLocale uk_UA")
    }
}
