//
//  DiaryViewModelProtocol.swift
//  Plekio
//
//  Created by Edward Gasparian on 24.08.2026.
//

import Foundation

@MainActor
protocol DiaryViewModelProtocol: ObservableObject {
    var entries: [DiaryEntrySnapshot] { get }

    /// Every entry's photos flattened into checkpoints, newest first.
    var photoCheckpoints: [DiaryPhotoCheckpoint] { get }

    // MARK: - Stats

    /// Average mood (out of 5) over the last 7 days; all entries if that window is empty.
    var avgMoodScore: Double { get }
    /// Average energy (out of 5) over the same window as `avgMoodScore`.
    var avgEnergyLevel: Double { get }
    var totalPhotosLogged: Int { get }
    /// Average sleep hours over the same window as `avgMoodScore`.
    var avgSleepHours: Double { get }
    var hasCheckedInToday: Bool { get }
    /// Nil when nothing has been logged today.
    var todaysEntry: DiaryEntrySnapshot? { get }

    // MARK: - Blood Pressure

    /// Newest first. Separate from entries: pressure can be measured many times a day.
    var bloodPressureReadings: [BloodPressureSnapshot] { get }

    // MARK: - Actions

    func fetchEntries()
    func deleteEntry(_ entry: DiaryEntrySnapshot)

    /// Saves (or updates today's) minimal entry with just a mood.
    func quickLog(mood: DiaryMood)

    func addBloodPressureReading(measuredAt: Date, systolic: Int, diastolic: Int, pulse: Int?)
    func deleteBloodPressureReading(_ reading: BloodPressureSnapshot)
    func deleteAllBloodPressureReadings()

    /// Photos the comparison screen opens on. Nil when there are fewer than two photos.
    func comparisonPair(for selection: [UUID]) -> (before: UUID, after: UUID)?
}

// MARK: - Comparison

extension DiaryViewModelProtocol {

    /// Two ticked photos, oldest first; otherwise earliest vs latest photo.
    func comparisonPair(for selection: [UUID]) -> (before: UUID, after: UUID)? {
        let byDate = photoCheckpoints.sorted { $0.entry.checkInDate < $1.entry.checkInDate }

        // A selection can outlive its deleted photo, so resolve it before trusting it.
        let ticked = selection.compactMap { id in byDate.first { $0.id == id } }
        if ticked.count == 2 {
            let ordered = ticked.sorted { $0.entry.checkInDate < $1.entry.checkInDate }
            return (ordered[0].id, ordered[1].id)
        }

        guard let earliest = byDate.first, let latest = byDate.last, byDate.count >= 2 else {
            return nil
        }
        return (earliest.id, latest.id)
    }
}
