//
//  CoursesScreen.swift
//  PlekioUITests
//
//  Created by Edward Gasparian on 18.11.2026.
//

import XCTest

@MainActor
struct CoursesScreen {

    let app: XCUIApplication

    var newCourseButton: XCUIElement { app.buttons[AccessibilityID.Courses.newCourse] }

    func row(_ courseName: String) -> XCUIElement {
        app.element(AccessibilityID.Courses.row(courseName))
    }

    /// Waits for the button first: right after the tab is tapped the Courses
    /// screen may not be there yet, and `tap()` doesn't wait for a missing element.
    func newCourse() -> NewCourseScreen {
        _ = newCourseButton.waitForExistence(timeout: XCUIElement.timeout)
        newCourseButton.tap()
        return NewCourseScreen(app: app)
    }
}
