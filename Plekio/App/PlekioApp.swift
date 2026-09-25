//
//  PlekioApp.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI

@main
struct PlekioApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @Environment(\.scenePhase) private var scenePhase
    
    @StateObject private var router = AppRouter()
    
    init() {
        // Created up front, not on first use: it has to be listening before the
        // first course is written.
        _ = DIContainer.shared.resolve(ReminderSyncCoordinator.self)
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
    /// Nothing was written, but time has passed: the queue only covers a window
    /// ahead of "now", so it is topped up whenever the user comes back.
    private func refreshAllNotifications() {
        DIContainer.shared.resolve(ReminderSyncCoordinator.self).sync()
    }
}
