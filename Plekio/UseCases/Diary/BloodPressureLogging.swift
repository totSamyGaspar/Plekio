//
//  BloodPressureLogging.swift
//  Plekio
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Foundation

// MARK: - BloodPressureError

/// A reading rejected by `BloodPressureRules`.
enum BloodPressureError: LocalizedError {
    case invalid(BloodPressureRules.Issue)

    var errorDescription: String? {
        String(localized: "This reading can't be saved. Check the numbers and try again.")
    }
}

// MARK: - BloodPressureLogging

@MainActor
final class BloodPressureLogging {

    // MARK: - Properties

    private let diary: any DiaryRepository
    private let errors: any ErrorReporting
    private let time: any TimeSource

    // MARK: - Init

    init(diary: any DiaryRepository, errors: any ErrorReporting, time: any TimeSource) {
        self.diary = diary
        self.errors = errors
        self.time = time
    }

    // MARK: - Public

    /// Validates, then writes. False if rejected or the write failed (error already reported).
    @discardableResult
    func save(measuredAt: Date, systolic: Int, diastolic: Int, pulse: Int?) -> Bool {
        if let issue = BloodPressureRules.issue(
            systolic: systolic, diastolic: diastolic, pulse: pulse,
            measuredAt: measuredAt, now: time.now
        ) {
            errors.report(BloodPressureError.invalid(issue))
            return false
        }
        return errors.run {
            try diary.saveBloodPressureReading(
                measuredAt: measuredAt, systolic: systolic, diastolic: diastolic, pulse: pulse
            )
        }
    }
}
