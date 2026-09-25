//
//  PendingBloodPressureReading.swift
//  Plekio
//
//  Shared "save a blood-pressure reading" logic: the diary screen's own button
//  and the form a reminder opens must write the same way and report failure the
//  same way. Same reason DoseLoggingUseCase exists for a dose.
//

import Foundation

@MainActor
enum PendingBloodPressureReading {

    @discardableResult
    static func save(
        measuredAt: Date,
        systolic: Int,
        diastolic: Int,
        pulse: Int?,
        dbService: any BloodPressureStoring,
        errors: any ErrorReporting
    ) -> Bool {
        errors.run {
            try dbService.saveBloodPressureReading(
                measuredAt: measuredAt, systolic: systolic, diastolic: diastolic, pulse: pulse
            )
        }
    }
}
