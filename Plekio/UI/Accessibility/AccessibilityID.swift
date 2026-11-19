//
//  AccessibilityID.swift
//  Plekio
//
//  Created by Edward Gasparian on 18.11.2026.
//

import Foundation

// MARK: - AccessibilityID

/// Identifiers UI tests find views by. Not shown or spoken: VoiceOver reads labels,
/// never these. Tests look views up by identifier, not by text, so they pass in
/// every language the app ships in.
///
/// Built into the UI test target as well, so a renamed identifier breaks the build
/// of the tests instead of failing them at run time. Plain strings for that reason:
/// the file must compile without the rest of the app.
nonisolated enum AccessibilityID {

    // MARK: - Today

    nonisolated enum Today {
        /// The "Log now" / "Log all" button on the Up next card.
        static let logUpNext = "today.upNext.logButton"
        /// "N of M doses logged" on the Up next card.
        static let upNextProgress = "today.upNext.progress"
        /// The title of the card's back, shown once every dose of the day is logged.
        static let dayComplete = "today.dayComplete.title"
        /// "Create a course", shown on Today before the first course.
        static let createFirstCourse = "today.empty.createCourse"
        static let undoMessage = "today.undo.message"
        static let undoButton = "today.undo.button"
        static let adherenceAverage = "today.adherence.average"
        static let adherenceBadge = "today.adherence.badge"

        /// The check button on one dose's card; doses are told apart by medication name.
        static func doseCheckmark(_ medicationName: String) -> String {
            "today.dose.\(medicationName).checkmark"
        }
    }

    // MARK: - Courses

    nonisolated enum Courses {
        static let newCourse = "courses.newCourseButton"
        static let filter = "courses.filter"

        static func row(_ courseName: String) -> String {
            "courses.row.\(courseName)"
        }
    }

    // MARK: - New course

    nonisolated enum NewCourse {
        static let name = "newCourse.nameField"
        static let addMedication = "newCourse.addMedicationButton"
        static let save = "newCourse.saveButton"
        static let cancel = "newCourse.cancelButton"
    }

    // MARK: - New medication

    nonisolated enum NewMedication {
        static let name = "newMedication.nameField"
        static let stock = "newMedication.stockField"
        static let lowStockThreshold = "newMedication.lowStockThresholdField"
        /// "That's the whole package or more…", under the threshold field.
        static let lowFromTheStartHint = "newMedication.lowFromTheStartHint"
        static let save = "newMedication.saveButton"
        static let cancel = "newMedication.cancelButton"
    }
}
