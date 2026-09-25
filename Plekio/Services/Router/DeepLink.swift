//
//  DeepLink.swift
//  Plekio
//
//  Where the app can be asked to go from outside a screen — today, a tapped
//  notification — and the tabs it can land on.
//
//  The router used to take these as separate calls, each parking its payload
//  in its own pair of optionals (`pendingPushMedicationIds` + `pendingPushTime`,
//  `pendingReminder` + `pendingDiarySubTab`), and the tabs were the integers 0
//  to 3 written at five call sites. A new kind of link meant another pair of
//  fields, another consume method and another buffer in AppDelegate. Now it is
//  one more case here, and the compiler lists every switch that has to handle it.
//

import Foundation

/// The tab bar, by name rather than by index.
enum AppTab: Hashable, CaseIterable {
    case today, courses, diary, settings
}

enum DeepLink: Equatable {

    /// A dose reminder's body was tapped: confirm the doses still open in that slot.
    case doseReminder(medicationIds: [UUID], slot: Date)

    /// A daily reminder was tapped: open the form it is about.
    case dailyReminder(DailyReminder)

    /// The tab the link lands on — the screen behind whatever it presents.
    var tab: AppTab {
        switch self {
        case .doseReminder: return .today
        case .dailyReminder: return .diary
        }
    }

    /// The diary sub-tab to show behind the form, if the link cares. The
    /// readings live on Mood & Trends: dismissing the blood-pressure form should
    /// leave the new measurement on screen, not the journal feed. The check-in
    /// is not about any one sub-tab, so the diary stays wherever it was.
    var diarySubTab: DiarySubTab? {
        switch self {
        case .dailyReminder(.bloodPressure): return .moodTrends
        case .dailyReminder(.diary), .doseReminder: return nil
        }
    }
}
