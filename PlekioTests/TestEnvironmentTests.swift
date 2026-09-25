//
//  TestEnvironmentTests.swift
//  PlekioTests
//
//  The test run's time zone and region are pinned in the Plekio scheme's Test
//  action (TZ=Europe/Berlin, -AppleLocale ru_RU). Tests build dates with
//  Calendar.current, so without the pin "today", midnight and the first day of
//  the week follow whatever machine runs them — a laptop in one zone, CI in
//  UTC. This test fails loudly when the pin is missing (another scheme, a
//  command line without it) instead of letting date tests fail at random.
//
//  Berlin because it has DST: a zone without one would hide the bugs that
//  only show on the night the clocks change.
//

import Testing
import Foundation

@Suite("Test environment")
struct TestEnvironmentTests {

    @Test("часовой пояс и регион тестов зафиксированы в схеме")
    func timeZoneAndRegionArePinned() {
        #expect(TimeZone.current.identifier == "Europe/Berlin",
                "Run tests with the Plekio scheme: its Test action sets TZ=Europe/Berlin")
        // ru_RU starts the week on Monday, which the weekly stats rely on.
        #expect(Calendar.current.firstWeekday == 2,
                "Run tests with the Plekio scheme: its Test action sets -AppleLocale ru_RU")
    }
}
