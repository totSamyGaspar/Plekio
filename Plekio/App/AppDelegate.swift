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
    private(set) lazy var launcher = AppLauncher(location: .appGroup(), open: AppDependencies.live(location:))

    // MARK: - UIApplicationDelegate

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        PlekioTips.configure()
        _ = launcher
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
            guard let self else { return }
            guard let dependencies = launcher.dependencies else {
                // An opening tap lands on the recovery screen; a lock-screen action would be lost.
                if intent.isBackgroundAction { await Self.reportNotRecorded() }
                return
            }
            await dependencies.notificationResponses.handle(intent)
        }
    }

    // MARK: - Store Not Open

    /// Take, Skip or Snooze couldn't be carried out. Says so at once, so the dose
    /// doesn't look logged; the tap opens the app on the recovery screen.
    private static func reportNotRecorded() async {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Dose not recorded")
        content.body = String(localized: "Plekio can't open its data right now. Open the app to see what to do.")
        let request = UNNotificationRequest(identifier: "DOSE_NOT_RECORDED", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
