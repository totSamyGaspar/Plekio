//
//  DeepLink.swift
//  Plekio
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Foundation

// MARK: - AppTab

enum AppTab: Hashable, CaseIterable {
    case today, diary, courses, settings
}

// MARK: - DeepLink

enum DeepLink: Equatable {

    // MARK: - Cases

    /// A dose reminder's body was tapped: confirm the doses still open in that slot.
    case doseReminder(medicationIds: [UUID], slot: Date)

    /// A daily reminder was tapped: open the form it is about.
    case dailyReminder(DailyReminder)

    // MARK: - Destination

    /// The tab the link lands on — the screen behind whatever it presents.
    var tab: AppTab {
        switch self {
        case .doseReminder: return .today
        case .dailyReminder: return .diary
        }
    }

    /// Diary sub-tab behind the form; nil leaves the diary where it was.
    /// Blood pressure lands on Mood & Trends so the new reading is visible.
    var diarySubTab: DiarySubTab? {
        switch self {
        case .dailyReminder(.bloodPressure): return .moodTrends
        case .dailyReminder(.diary), .doseReminder: return nil
        }
    }
}
