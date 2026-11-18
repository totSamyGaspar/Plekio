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

    func newCourse() -> NewCourseScreen {
        newCourseButton.tap()
        return NewCourseScreen(app: app)
    }
}
