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
        let reading = BloodPressureReading(
            measuredAt: measuredAt,
            // Same clamping idiom as sleepHours above: a typo like 1200/80 would
            // otherwise flatten the whole chart.
            systolic: BloodPressureReading.systolicRange.clamping(systolic),
            diastolic: BloodPressureReading.diastolicRange.clamping(diastolic),
            pulse: pulse.map { BloodPressureReading.pulseRange.clamping($0) }
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
