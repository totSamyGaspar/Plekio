//
//  NewCourseUITests.swift
//  PlekioUITests
//
//  Created by Edward Gasparian on 18.11.2026.
//

import XCTest

final class NewCourseUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The main path: a course made from the Courses tab is listed there and its
    /// dose shows on Today. The form's defaults start the course today, at the
    /// current time, so the dose is always on today's list.
    @MainActor
    func testCreatedCourse_appearsInCoursesAndOnToday() {
        let app = XCUIApplication.launchPlekio(seed: .empty)
        let tabBar = TabBar(app: app)
        let courseName = "Morning pills"
        let medicationName = "Magnesium"

        let courses = tabBar.openCourses()
        assertExists(courses.newCourseButton, in: app)
        let newCourse = courses.newCourse()
        assertExists(newCourse.nameField, in: app)
        newCourse.typeName(courseName)

        let newMedication = newCourse.addMedication()
        assertExists(newMedication.nameField, in: app)
        newMedication.typeName(medicationName)
        newMedication.save()

        assertExists(newCourse.saveButton, in: app)
        XCTAssertTrue(newCourse.saveButton.isEnabled, "Save is off with a name and a medication")
        newCourse.save()

        assertExists(courses.row(courseName), in: app, "The new course isn't listed")

        let today = tabBar.openToday()
        XCTAssertTrue(app.scrollTo(today.doseCheckmark(medicationName)), "The new dose isn't on Today")
    }

    /// A name of spaces only must not be saved.
    @MainActor
    func testBlankMedicationName_cannotBeSaved() {
        let app = XCUIApplication.launchPlekio(seed: .empty)

        let newCourse = TabBar(app: app).openCourses().newCourse()
        assertExists(newCourse.addMedicationButton, in: app)
        let newMedication = newCourse.addMedication()
        assertExists(newMedication.nameField, in: app)
        newMedication.typeName("   ")

        // Known bug: Save checks `name.isEmpty` without trimming. Fixed on the
        // add_medication_validation branch; remove XCTExpectFailure there, or this
        // test fails as an unexpected pass.
        XCTExpectFailure("Save accepts a name of spaces until add_medication_validation lands") {
            XCTAssertFalse(newMedication.saveButton.isEnabled)
        }
    }
}
