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

    /// Logging the Up next slot changes the count, and Undo puts it back.
    /// Compares the label before and after rather than exact numbers: which slot
    /// is up next depends on the time the test runs.
    @MainActor
    func testLogUpNext_thenUndo() {
        let app = XCUIApplication.launchPlekio(seed: .today)
        let today = TodayScreen(app: app)

        assertExists(today.logUpNextButton, in: app)
        assertExists(today.upNextProgress, in: app)
        let before = today.upNextProgress.label

        today.logUpNextButton.tap()
        assertExists(today.undoButton, in: app)
        XCTAssertNotEqual(today.upNextProgress.label, before)

        today.undoButton.tap()
        assertExists(today.logUpNextButton, in: app)
        XCTAssertEqual(today.upNextProgress.label, before)
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
