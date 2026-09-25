//
//  DatabaseService+BloodPressure.swift
//  Plekio
//

import Foundation
import OSLog
import SwiftData

/// Blood-pressure readings.
extension DatabaseService: BloodPressureStoring {

    // MARK: - Blood pressure

    func saveBloodPressureReading(measuredAt: Date, systolic: Int, diastolic: Int, pulse: Int?) throws {
        // Stored as given. Validation is BloodPressureLogging's: it used to be
        // clamping here, which quietly turned a typed 1200/80 into 300/80 — a
        // number nobody measured, in a report meant for a doctor — and still
        // let an inverted 80/120 through.
        let reading = BloodPressureReading(
            measuredAt: measuredAt,
            systolic: systolic,
            diastolic: diastolic,
            pulse: pulse
        )
        context.insert(reading)
        // Posted on the diary channel: the readings live on the diary's own
        // screen, and it is the only subscriber that needs to redraw.
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

    /// Wipes the whole pressure history in one write.
    ///
    /// Deleted one by one rather than through a batch delete: a batch bypasses
    /// the context, so the rollback in `commit` would have nothing to undo if the
    /// save failed — and this is the one action here with no way back.
    func deleteAllBloodPressureReadings() throws {
        let readings = fetchAllBloodPressureReadings()
        guard !readings.isEmpty else { return }

        for reading in readings {
            context.delete(reading)
        }
        try persistence.commit([.diary])
    }
}
