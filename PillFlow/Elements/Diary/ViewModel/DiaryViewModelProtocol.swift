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

    func fetchEntries()
    func deleteEntry(_ entry: DiaryEntry)

    /// One-tap mood logging from the home screen's quick-pick chips — saves a
    /// minimal entry immediately, as an alternative to the full check-in form.
    func quickLog(mood: DiaryMood)
}
