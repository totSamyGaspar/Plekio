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
    
    // У каждого таба своя независимая стопка пушей
    @Published var coursesPath = NavigationPath()
    
    // Активный шит (модалка)
    @Published var activeSheet: SheetRoute?
    @Published var activeFullScreen: SheetRoute?
    
    // Активный таб
    @Published var selectedTab: Int = 0
    
    // MARK: - Push navigation
    
    func push(_ route: Route) {
        // Сейчас push только для courses-таба,
        // при масштабировании добавишь параметр tab
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
    
    // Хранилище для "отложенного" перехода из пуш-уведомления
    @Published var pendingPushMedicationIds: [UUID]?
    @Published var pendingPushTime: Date?
    
    func consumePendingPush() -> ([UUID], Date)? {
        guard let ids = pendingPushMedicationIds, let time = pendingPushTime else { return nil }
        pendingPushMedicationIds = nil
        pendingPushTime = nil
        return (ids, time)
    }
}
