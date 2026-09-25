//
//  AppDelegate.swift
//  Plekio
//
//  Created by Edward Gasparian on 03.05.2026.
//

import SwiftUI
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    // MARK: - Properties

    /// Owned here, not by PlekioApp: notification actions can arrive on a cold
    /// launch before any view exists and must use the same graph as the UI.
    private(set) lazy var dependencies: AppDependencies = .live()

    // MARK: - UIApplicationDelegate

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        _ = dependencies
        return true
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Only unwraps the response; the testable logic lives in NotificationIntent
    /// and NotificationResponseHandler.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        guard let intent = NotificationIntent.parse(
            userInfo: response.notification.request.content.userInfo,
            actionIdentifier: response.actionIdentifier
        ) else {
            completionHandler()
            return
        }

        Task { @MainActor [weak self] in
            // Complete only after the work: iOS may suspend the app mid-reschedule.
            defer { completionHandler() }
            await self?.dependencies.notificationResponses.handle(intent)
        }
    }
}
