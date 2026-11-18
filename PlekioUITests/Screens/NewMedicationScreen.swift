//
//  NewMedicationScreen.swift
//  PlekioUITests
//
//  Created by Edward Gasparian on 18.11.2026.
//

import XCTest

@MainActor
struct NewMedicationScreen {

    let app: XCUIApplication

    // MARK: - Elements

    var nameField: XCUIElement { app.textFields[AccessibilityID.NewMedication.name] }
    var saveButton: XCUIElement { app.buttons[AccessibilityID.NewMedication.save] }
    var cancelButton: XCUIElement { app.buttons[AccessibilityID.NewMedication.cancel] }

    // MARK: - Actions

    func typeName(_ name: String) {
        nameField.tap()
        nameField.typeText(name)
    }

    func save() {
        saveButton.tap()
    }
}
