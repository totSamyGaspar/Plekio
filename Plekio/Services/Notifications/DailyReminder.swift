//
//  DailyReminder.swift
//  Plekio
//
//  Created by Edward Gasparian on 04.09.2026.
//

import Foundation

/// A reminder firing at fixed times every day. Times are minutes since midnight.
/// Must be re-armed after a course reschedule clears the pending queue.
enum DailyReminder: String, CaseIterable, Identifiable, Sendable {

    // MARK: - Cases

    case diary
    case bloodPressure

    var id: String { rawValue }

    /// userInfo key for the reminder kind; dose reminders carry `medicationIds` instead.
    static let userInfoKey = "kind"

    // MARK: - Shape

    /// Max fires per day; each time permanently uses one of iOS's 64 pending slots.
    var maxTimes: Int {
        switch self {
        case .diary: return 1
        case .bloodPressure: return 3
        }
    }

    var defaultMinutesOfDay: [Int] {
        switch self {
        case .diary: return [21 * 60]
        case .bloodPressure: return [9 * 60]
        }
    }

    // MARK: - Stored Settings

    /// Storage key is migration-sensitive: existing diary reminders use it.
    var enabledKey: String { "\(rawValue)ReminderEnabled" }

    var timesKey: String { "\(rawValue)ReminderMinutesOfDay" }

    /// Legacy single-time key, still read so existing reminders keep their time.
    var legacyMinuteOfDayKey: String { "\(rawValue)ReminderMinuteOfDay" }

    // MARK: - Raw Times

    /// Parses the comma-separated list, clamped to the day and capped at `limit`.
    /// Not sorted: keeps row order stable while editing.
    nonisolated static func minutes(fromRaw raw: String, limit: Int) -> [Int] {
        raw.split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .map(MinuteOfDay.clamp)
            .prefix(limit)
            .map { $0 }
    }

    nonisolated static func raw(from minutes: [Int]) -> String {
        minutes.map(String.init).joined(separator: ",")
    }

    // MARK: - Notification Identity

    /// Fixed identifiers so re-arming replaces requests; slot 0 keeps the legacy bare id.
    func requestIdentifier(at index: Int) -> String {
        let base: String
        switch self {
        case .diary: base = "DIARY_REMINDER"
        case .bloodPressure: base = "BLOOD_PRESSURE_REMINDER"
        }
        return index == 0 ? base : "\(base)_\(index)"
    }

    /// Every identifier across all slots, used or not, for cancelling.
    var allRequestIdentifiers: [String] {
        (0..<maxTimes).map(requestIdentifier(at:))
    }

    /// Separate per reminder so actions added to one never appear on the other.
    var categoryIdentifier: String {
        switch self {
        case .diary: return "DIARY_REMINDER_CATEGORY"
        case .bloodPressure: return "BLOOD_PRESSURE_REMINDER_CATEGORY"
        }
    }

    // MARK: - Wording

    var notificationTitle: String {
        switch self {
        case .diary:
            return String(localized: "📔 Time for your check-in")
        case .bloodPressure:
            return String(localized: "🩺 Time to measure your blood pressure")
        }
    }

    var notificationBody: String {
        switch self {
        case .diary:
            return String(localized: "Log how you feel today: mood, energy and symptoms")
        case .bloodPressure:
            return String(localized: "Take a reading and log it in your diary")
        }
    }

    var settingsTitle: LocalizedStringResource {
        switch self {
        case .diary: return "Diary reminder"
        case .bloodPressure: return "Blood pressure reminder"
        }
    }

    var settingsIcon: String {
        switch self {
        case .diary: return "text.book.closed.fill"
        case .bloodPressure: return "heart.text.square.fill"
        }
    }
}
