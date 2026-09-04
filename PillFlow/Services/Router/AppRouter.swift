//
//  AppRouter.swift
//  PillFlow
//
//  Created by Edward Gasparian on 14.06.2026.
//

import SwiftUI
import Combine

@MainActor
final class AppRouter: ObservableObject {
    
    @Published var coursesPath = NavigationPath()

    @Published var activeSheet: SheetRoute?
    @Published var activeFullScreen: SheetRoute?

    @Published var selectedTab: Int = 0

    // MARK: - Sheet presentation
    
    func present(_ sheet: SheetRoute) {
        activeSheet = sheet
    }
    
    func presentFullScreen(_ sheet: SheetRoute) {
        activeFullScreen = sheet
    }
    
    func dismissSheet() {
        activeSheet = nil
        activeFullScreen = nil
    }
    
    // MARK: - Deep link / push notification handling
    
    func handlePushNotification(medicationIds: [UUID], time: Date) {
        selectedTab = 0
        self.pendingPushMedicationIds = medicationIds
        self.pendingPushTime = time
    }
    
    // Push navigation target, parked here until the destination screen consumes it.
    @Published var pendingPushMedicationIds: [UUID]?
    @Published var pendingPushTime: Date?
    
    /// A tapped daily reminder: switch to the diary and open what the reminder
    /// is for. Parked the same way as a dose push, because the same thing breaks
    /// it — on a cold launch the request arrives before the tab bar is in the
    /// hierarchy.
    @Published var pendingReminder: DailyReminder?

    /// Which diary sub-tab to land on, set alongside a reminder so the screen
    /// behind the sheet is the one the reminder is about.
    @Published var pendingDiarySubTab: DiarySubTab?

    func handleReminder(_ reminder: DailyReminder) {
        selectedTab = 2
        pendingReminder = reminder

        switch reminder {
        // The check-in is not about any one sub-tab, so the diary opens wherever
        // the user left it.
        case .diary:
            break
        // The readings live on Mood & Trends: dismissing the form should leave
        // the new measurement on screen, not the journal feed.
        case .bloodPressure:
            pendingDiarySubTab = .moodTrends
        }
    }

    func consumePendingReminder() -> DailyReminder? {
        guard let pendingReminder else { return nil }
        self.pendingReminder = nil
        return pendingReminder
    }

    func consumePendingDiarySubTab() -> DiarySubTab? {
        guard let pendingDiarySubTab else { return nil }
        self.pendingDiarySubTab = nil
        return pendingDiarySubTab
    }

    func consumePendingPush() -> ([UUID], Date)? {
        guard let ids = pendingPushMedicationIds, let time = pendingPushTime else { return nil }
        pendingPushMedicationIds = nil
        pendingPushTime = nil
        return (ids, time)
    }
}
