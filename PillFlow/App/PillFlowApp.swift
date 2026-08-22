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
        
        let activeCourses = dbService.fetchAllCourses().filter { $0.endDate >= Date() }

        // Goes through NotificationServiceProtocol rather than calling
        // UNUserNotificationCenter directly, consistent with the rest of the
        // app's DI usage and mockable in tests.
        notifService.removeAllPending()

        notifService.scheduleNotifications(activeCourses: activeCourses)
    }
}
