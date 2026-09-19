//
//  DiaryViewModelProtocol.swift
//  PillFlow
//
//  Created by Edward Gasparian on 24.08.2026.
//

import Foundation

@MainActor
protocol DiaryViewModelProtocol: ObservableObject {
    var entries: [DiaryEntry] { get }
    
    /// Every entry's photos flattened into checkpoints. Recomputed once per data
    /// change rather than on every access from a view.
    var photoCheckpoints: [DiaryPhotoCheckpoint] { get }
    
    // MARK: - Home screen stats (derived from `entries`)
    
    /// Average mood score (out of 5) over the last 7 days — falls back to all
    /// entries if nothing was logged in that window, so the stat isn't just "0".
    var avgMoodScore: Double { get }
    /// Average energy level (out of 5) over the same 7-day window as avgMoodScore.
    var avgEnergyLevel: Double { get }
    /// Total number of progress photos logged across all entries.
    var totalPhotosLogged: Int { get }
    /// Average sleep hours over the same 7-day window as avgMoodScore.
    var avgSleepHours: Double { get }
    /// Whether a check-in already exists for today.
    var hasCheckedInToday: Bool { get }
    /// Today's entry, if one has already been logged — backs the home
    /// screen's "today's check-in" summary card.
    var todaysEntry: DiaryEntry? { get }
    
    /// Blood-pressure measurements, newest first. Kept beside the entries
    /// rather than inside them: pressure is measured as often as the person
    /// likes, while a check-in happens once a day.
    var bloodPressureReadings: [BloodPressureReading] { get }
    
    func fetchEntries()
    func deleteEntry(_ entry: DiaryEntry)
    
    /// One-tap mood logging from the home screen's quick-pick chips — saves a
    /// minimal entry immediately, as an alternative to the full check-in form.
    func quickLog(mood: DiaryMood)
    
    func addBloodPressureReading(measuredAt: Date, systolic: Int, diastolic: Int, pulse: Int?)
    func deleteBloodPressureReading(_ reading: BloodPressureReading)
    func deleteAllBloodPressureReadings()
    
    /// Which two photos the comparison screen should open on, given what the
    /// user has ticked in the gallery. `nil` when there are not two photos to
    /// compare at all — the caller decides what to show instead.
    func comparisonPair(for selection: [UUID]) -> (before: UUID, after: UUID)?
}

extension DiaryViewModelProtocol {
    
    /// Two ticked checkpoints are compared oldest first, whatever order they
    /// were ticked in. Anything else — nothing ticked, one ticked, or ticks left
    /// over from photos that have since been deleted — falls back to the
    /// earliest photo against the latest, which is the comparison people mean by
    /// "show me my progress".
    ///
    /// Derived entirely from `photoCheckpoints`, so it is written once here
    /// rather than in the view model and again in its preview mock.
    func comparisonPair(for selection: [UUID]) -> (before: UUID, after: UUID)? {
        let byDate = photoCheckpoints.sorted { $0.entry.checkInDate < $1.entry.checkInDate }
        
        // Resolved against the checkpoints rather than trusted: a selection can
        // outlive the photo it points at, and an unresolved one leaves the button
        // doing nothing, which reads as the app being broken.
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
