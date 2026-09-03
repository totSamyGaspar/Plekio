//
//  PillFlowApp.swift
//  PillFlow
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI

@main
struct PillFlowApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @Environment(\.scenePhase) private var scenePhase
    
    @StateObject private var router = AppRouter()
    
    init() {
        _ = DIContainer.shared
        MainTabView.configureTabBarAppearance()
        AppAppearance.configureSliders()
    }
    
    var body: some Scene {
        WindowGroup {
            SplashView()
                .environmentObject(router)
                .onAppear {
                    appDelegate.router = router
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        refreshAllNotifications()
                    }
                }
        }
    }
    private func refreshAllNotifications() {
        let dbService = DIContainer.shared.resolve(DatabaseServiceProtocol.self)
        let notifService = DIContainer.shared.resolve(NotificationServiceProtocol.self)

        Task { await notifService.rescheduleAll(using: dbService) }
    }
}
