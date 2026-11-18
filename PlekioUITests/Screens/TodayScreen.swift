//
//  TodayScreen.swift
//  PlekioUITests
//
//  Created by Edward Gasparian on 18.11.2026.
//

import XCTest

@MainActor
struct TodayScreen {

    let app: XCUIApplication

    // MARK: - Elements

    var logUpNextButton: XCUIElement { app.buttons[AccessibilityID.Today.logUpNext] }
    /// "N of M doses logged" on the Up next card. Found by its text for now: the
    /// identifier on this Text didn't show up in the hierarchy on the first run
    /// (iOS 27). The back of the card has the same text but is hidden from
    /// accessibility until it turns, so this matches the front only.
    var upNextProgress: XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label ENDSWITH %@", "doses logged")).firstMatch
    }
    var dayComplete: XCUIElement { app.element(AccessibilityID.Today.dayComplete) }
    var undoButton: XCUIElement { app.buttons[AccessibilityID.Today.undoButton] }
    var createFirstCourseButton: XCUIElement { app.buttons[AccessibilityID.Today.createFirstCourse] }

    func doseCheckmark(_ medicationName: String) -> XCUIElement {
        app.buttons[AccessibilityID.Today.doseCheckmark(medicationName)]
    }

    // MARK: - Actions

    func createFirstCourse() -> NewCourseScreen {
        createFirstCourseButton.tap()
        return NewCourseScreen(app: app)
    }
}
