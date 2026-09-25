//
//  BloodPressureLogging.swift
//  Plekio
//
//  Saving one blood-pressure reading — the diary screen's button and the form a
//  reminder opens both come here.
//
//  Replaces PendingBloodPressureReading, which only forwarded to the repository:
//  the plausibility rules lived in the entry form alone, and the store clamped
//  whatever reached it. Anything that wrote around that form — another screen,
//  an import later — could put an inverted 80/120 into the report for the
//  doctor. The rules are now checked here, on the write, whatever the caller.
//

import Foundation

/// A reading the rules refuse. The form never offers Save for one, so reaching
/// this means a caller skipped the form's check.
enum BloodPressureError: LocalizedError {
    case invalid(BloodPressureRules.Issue)

    var errorDescription: String? {
        String(localized: "This reading can't be saved. Check the numbers and try again.")
    }
}

@MainActor
final class BloodPressureLogging {

    private let diary: any DiaryRepository
    private let errors: any ErrorReporting
    private let time: any TimeSource

    init(diary: any DiaryRepository, errors: any ErrorReporting, time: any TimeSource) {
        self.diary = diary
        self.errors = errors
        self.time = time
    }

    /// Validates, then writes. False when the reading was refused or the write
    /// failed; either way the reason has been reported.
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
