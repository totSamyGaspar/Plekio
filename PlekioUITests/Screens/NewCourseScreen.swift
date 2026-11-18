//
//  NewCourseScreen.swift
//  PlekioUITests
//
//  Created by Edward Gasparian on 18.11.2026.
//

import XCTest

@MainActor
struct NewCourseScreen {

    let app: XCUIApplication

    // MARK: - Elements

    var nameField: XCUIElement { app.textFields[AccessibilityID.NewCourse.name] }
    var addMedicationButton: XCUIElement { app.buttons[AccessibilityID.NewCourse.addMedication] }
    var saveButton: XCUIElement { app.buttons[AccessibilityID.NewCourse.save] }
    var cancelButton: XCUIElement { app.buttons[AccessibilityID.NewCourse.cancel] }

    // MARK: - Actions

    func typeName(_ name: String) {
        nameField.tap()
        nameField.typeText(name)
    }

    func addMedication() -> NewMedicationScreen {
        addMedicationButton.tap()
        return NewMedicationScreen(app: app)
    }

    func save() {
        saveButton.tap()
    }
}
