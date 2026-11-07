//
//  StreakRules.swift
//  Plekio
//
//  Created by Edward Gasparian on 21.10.2026.
//

import Foundation

// MARK: - StreakRules

/// What counts as a day kept. One rule for Today and the widget, so the two
/// never show different streaks.
nonisolated enum StreakRules {

    /// How far back the streak is counted; also the history the caller must read.
    static let lookbackDays = 30

    /// Fraction of a day's doses that must be logged for the day to count.
    static let threshold = 0.9

    /// Today and the `lookbackDays` before it, newest first: the days `streak` reads.
    static func days(endingAt today: Date, calendar: Calendar) -> [Date] {
        (0...lookbackDays).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
    }

    /// Consecutive days at or above `threshold`. Today can add but never break it.
    /// The denominator is the schedule (`fetchPills`), not the logged `DoseLog` records.
    /// - Parameter today: start of today; `pillsByDay` is keyed by start of day.
    static func streak(pillsByDay: [Date: [PillDose]], today: Date, calendar: Calendar) -> Int {
        var streak = 0

        if let todayAdherence = adherence(of: pillsByDay[today] ?? []),
           todayAdherence >= threshold {
            streak += 1
        }

        // Past days are closed and can break the streak.
        for offset in 1...lookbackDays {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { break }

            // Days with nothing scheduled neither break nor extend the streak.
            guard let dayAdherence = adherence(of: pillsByDay[day] ?? []) else { continue }
            guard dayAdherence >= threshold else { break }

            streak += 1
        }

        return streak
    }

    /// Fraction of the day's doses that were logged; `nil` if nothing was scheduled.
    static func adherence(of scheduled: [PillDose]) -> Double? {
        guard !scheduled.isEmpty else { return nil }
        let taken = scheduled.filter(\.isTaken).count
        return Double(taken) / Double(scheduled.count)
    }
}
