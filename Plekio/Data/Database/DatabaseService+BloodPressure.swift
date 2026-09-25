//
//  DatabaseService+BloodPressure.swift
//  Plekio
//
//  Created by Edward Gasparian on 14.09.2026.
//

import Foundation
import OSLog
import SwiftData

extension DatabaseService: BloodPressureStoring {

    // MARK: - BloodPressureStoring

    func saveBloodPressureReading(measuredAt: Date, systolic: Int, diastolic: Int, pulse: Int?) throws {
        // Stored as given; never clamp here. Validation belongs to BloodPressureLogging.
        let reading = BloodPressureReading(
            measuredAt: measuredAt,
            systolic: systolic,
            diastolic: diastolic,
            pulse: pulse
        )
        context.insert(reading)
        try persistence.commit([.diary])
    }

    func fetchAllBloodPressureReadings() -> [BloodPressureReading] {
        let descriptor = FetchDescriptor<BloodPressureReading>(
            sortBy: [SortDescriptor(\.measuredAt, order: .reverse)]
        )
        return fetch(descriptor)
    }

    func deleteBloodPressureReading(_ reading: BloodPressureReading) throws {
        context.delete(reading)
        try persistence.commit([.diary])
    }

    /// Deletes one by one, not by batch: a batch bypasses the context, so
    /// `commit`'s rollback could not undo a failed save.
    func deleteAllBloodPressureReadings() throws {
        let readings = fetchAllBloodPressureReadings()
        guard !readings.isEmpty else { return }

        for reading in readings {
            context.delete(reading)
        }
        try persistence.commit([.diary])
    }
}
