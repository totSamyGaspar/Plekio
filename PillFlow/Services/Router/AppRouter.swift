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
    
    // Each tab has its own independent navigation stack.
    @Published var coursesPath = NavigationPath()

    // Currently presented sheet / full-screen cover.
    @Published var activeSheet: SheetRoute?
    @Published var activeFullScreen: SheetRoute?

    @Published var selectedTab: Int = 0

    // MARK: - Push navigation

    func push(_ route: Route) {
        // Only pushes onto the courses tab for now; add a `tab` parameter
        // here if navigation needs to scale to other tabs.
        coursesPath.append(route)
    }
    
    func popToRoot() {
        coursesPath = NavigationPath()
    }
    
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
    
    // Holds a pending navigation target from a push notification until it's consumed.
    @Published var pendingPushMedicationIds: [UUID]?
    @Published var pendingPushTime: Date?
    
    func consumePendingPush() -> ([UUID], Date)? {
        guard let ids = pendingPushMedicationIds, let time = pendingPushTime else { return nil }
        pendingPushMedicationIds = nil
        pendingPushTime = nil
        return (ids, time)
    }
}
