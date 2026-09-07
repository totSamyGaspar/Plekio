//
//  AppDelegate.swift
//  PillFlow
//
//  Created by Edward Gasparian on 03.05.2026.
//

import SwiftUI
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    /// A notification tap can arrive before SwiftUI has drawn the first screen and
    /// assigned the router, so the payload is buffered and replayed the moment the
    /// router appears. Without this a tap on a cold launch was silently lost.
    weak var router: AppRouter? {
        didSet { flushBufferedPush() }
    }

    private var bufferedPush: (medicationIds: [UUID], time: Date)?
    private var bufferedReminder: DailyReminder?

    private func flushBufferedPush() {
        guard let router else { return }

        if let push = bufferedPush {
            bufferedPush = nil
            router.handlePushNotification(medicationIds: push.medicationIds, time: push.time)
        }

        if let reminder = bufferedReminder {
            bufferedReminder = nil
            router.handleReminder(reminder)
        }
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {

        let userInfo = response.notification.request.content.userInfo

        // The daily reminders carry no medicationIds, so they have to be
        // recognised before the dose branch's guard drops them as malformed.
        if let kind = userInfo[DailyReminder.userInfoKey] as? String,
           let reminder = DailyReminder(rawValue: kind) {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if let router = self.router {
                    router.handleReminder(reminder)
                } else {
                    self.bufferedReminder = reminder
                }
            }
            completionHandler()
            return
        }

        guard let medIdStrings = userInfo["medicationIds"] as? [String],
              let timeInterval = userInfo["time"] as? TimeInterval else {
            completionHandler()
            return
        }

        let medIds = medIdStrings.compactMap { UUID(uuidString: $0) }
        let names = userInfo["medicationNames"] as? [String] ?? []
        let scheduledTime = Date(timeIntervalSince1970: timeInterval)
        let action = response.actionIdentifier

        Task { @MainActor [weak self] in
            // Called only once the work is done, not before it starts. iOS may
            // suspend the app as soon as this returns, and logging a dose now ends
            // in a full reschedule — announcing "handled" first meant that
            // reschedule could be cut off halfway.
            defer { completionHandler() }

            switch action {
            // The button already answers the question, so it logs the dose instead of
            // opening a modal asking it again — it only switches to today's tab.
            case NotificationAction.take:
                guard let self else { return }
                await self.logDoses(medicationIds: medIds, scheduledTime: scheduledTime)
                self.router?.selectedTab = 0

            case NotificationAction.snooze:
                let notifService = DIContainer.shared.resolve(NotificationServiceProtocol.self)
                await notifService.scheduleSnooze(for: medIdStrings, names: names)

            // A skip is the absence of a log, not a state of its own. iOS removes the
            // notification itself once any action is chosen.
            case NotificationAction.skip:
                break

            // A plain tap on the notification body: open the app and show the modal.
            default:
                guard let self else { return }
                if let router = self.router {
                    router.handlePushNotification(medicationIds: medIds, time: scheduledTime)
                } else {
                    self.bufferedPush = (medIds, scheduledTime)
                }
            }
        }
    }

    /// Logs the doses of the slot that aren't logged yet.
    ///
    /// Idempotent by way of `PendingDose.unlogged`: `togglePill` is a toggle, so
    /// without that filter a second "Take Now" would clear the mark it just set.
    private func logDoses(medicationIds: [UUID], scheduledTime: Date) async {
        let dbService = DIContainer.shared.resolve(DatabaseServiceProtocol.self)
        let notifService = DIContainer.shared.resolve(NotificationServiceProtocol.self)

        await PendingDose.markTaken(
            PendingDose.unlogged(medicationIds: medicationIds, scheduledTime: scheduledTime, in: dbService),
            dbService: dbService,
            notificationService: notifService
        )
    }
}
