//
//  TodayUITests.swift
//  PlekioUITests
//
//  Created by Edward Gasparian on 18.11.2026.
//

import XCTest

final class TodayUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Before the first course Today offers to create one, and the button opens the form.
    @MainActor
    func testEmptyDay_offersToCreateACourse() {
        let app = XCUIApplication.launchPlekio(seed: .empty)
        let today = TodayScreen(app: app)

        assertExists(today.createFirstCourseButton, in: app)
        let newCourse = today.createFirstCourse()
        assertExists(newCourse.nameField, in: app)
    }

    /// At 08:30 the dose due now is up next on its own. Logging it counts one of
    /// two, and Undo puts it back.
    @MainActor
    func testLogUpNext_thenUndo() {
        let app = XCUIApplication.launchPlekio(seed: .today, at: TestTime.morning)
        let today = TodayScreen(app: app)

        assertExists(today.logUpNextButton, in: app)
        assertExists(today.upNextProgress, in: app)
        XCTAssertEqual(today.upNextProgress.label, "0 of 2 doses logged")

        today.logUpNextButton.tap()
        assertExists(today.undoButton, in: app)
        XCTAssertEqual(today.upNextProgress.label, "1 of 2 doses logged")

        today.undoButton.tap()
        assertExists(today.logUpNextButton, in: app)
        XCTAssertEqual(today.upNextProgress.label, "0 of 2 doses logged")
    }

    /// Past its grace hour a dose is marked missed, and it can still be logged.
    @MainActor
    func testMissedDose_canStillBeLogged() {
        let app = XCUIApplication.launchPlekio(seed: .today, at: TestTime.lateMorning)
        let today = TodayScreen(app: app)
        let checkmark = today.doseCheckmark(SeedNames.morning)

        XCTAssertTrue(app.scrollTo(checkmark), "No dose card for \(SeedNames.morning)")
        XCTAssertEqual(checkmark.label, "Log the missed dose of \(SeedNames.morning)")

        checkmark.tap()
        XCTAssertEqual(checkmark.label, "Undo logging \(SeedNames.morning)")
    }

    /// Logging every dose turns the card over to "Day complete".
    @MainActor
    func testLoggingEveryDose_completesTheDay() {
        let app = XCUIApplication.launchPlekio(seed: .today)
        let today = TodayScreen(app: app)

        for name in [SeedNames.morning, SeedNames.dueNow] {
            let checkmark = today.doseCheckmark(name)
            XCTAssertTrue(app.scrollTo(checkmark), "No dose card for \(name)")
            checkmark.tap()
        }

        // The card is at the top; it stays in the hierarchy while scrolled away.
        assertExists(today.dayComplete, in: app)
    }
}
