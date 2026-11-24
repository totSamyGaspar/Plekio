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
    /// "N of M doses logged" on the Up next card.
    var upNextProgress: XCUIElement { app.element(AccessibilityID.Today.upNextProgress) }
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
