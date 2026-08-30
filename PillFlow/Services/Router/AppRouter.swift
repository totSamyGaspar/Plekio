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
    
    /// Diary reminder: switch to the diary and open the check-in form. Parked
    /// the same way as a dose push, because the same thing breaks it — on a cold
    /// launch the request arrives before the tab bar is in the hierarchy.
    @Published var pendingDiaryCheckIn = false

    func handleDiaryReminder() {
        selectedTab = 2
        pendingDiaryCheckIn = true
    }

    func consumePendingDiaryCheckIn() -> Bool {
        guard pendingDiaryCheckIn else { return false }
        pendingDiaryCheckIn = false
        return true
    }

    func consumePendingPush() -> ([UUID], Date)? {
        guard let ids = pendingPushMedicationIds, let time = pendingPushTime else { return nil }
        pendingPushMedicationIds = nil
        pendingPushTime = nil
        return (ids, time)
    }
}
