//
//  NotificationService.swift
//  PillFlow
//
//  Created by Edward Gasparian on 02.05.2026.
//

import Foundation
import UserNotifications

final class NotificationService: NotificationServiceProtocol {

    /// Single source of truth for the snooze delay, so the category action's
    /// title and the actual scheduled trigger can't drift out of sync.
    private static let snoozeInterval: TimeInterval = 15 * 60

    // MARK: - Notification Categories

    private func registerNotificationCategories() {
        let center = UNUserNotificationCenter.current()

        let takeAction = UNNotificationAction(identifier: "ACTION_TAKE", title: "Take Now", options: .foreground)
        let snoozeAction = UNNotificationAction(identifier: "ACTION_SNOOZE", title: "Snooze 15m", options: [])
        let skipAction = UNNotificationAction(identifier: "ACTION_SKIP", title: "Skip", options: .destructive)

        let category = UNNotificationCategory(
            identifier: "PILL_REMINDER_CATEGORY",
            actions: [takeAction, snoozeAction, skipAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        center.setNotificationCategories([category])
    }

    // MARK: - Permission

    func requestPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Notifications authorized by user")
                self.registerNotificationCategories()
            } else if let error = error {
                print("🚨 Permission error: \(error.localizedDescription)")
            }
        }
    }

    /// Single entry point for clearing all scheduled notifications, so callers
    /// don't reach into UNUserNotificationCenter directly.
    func removeAllPending() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: - Schedule Building

    /// Pure, side-effect-free computation of what needs to be scheduled, kept
    /// separate from scheduleNotifications so it can be unit tested without a
    /// real notification center. Handles two rules: grouping multiple
    /// medications that share a trigger time into a single push, and skipping
    /// slots that are already logged as taken. `now`/`calendar` default to
    /// live values so production behavior is unaffected; tests inject fixed ones.
    static func buildScheduleMap(
        activeCourses: [TreatmentCourse],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Date: [(courseName: String, medication: MedicationItem)]] {
        let today = calendar.startOfDay(for: now)
        let maxDate = calendar.date(byAdding: .day, value: 2, to: today) ?? today

        // Groups medications by their exact trigger time.
        var scheduleMap: [Date: [(courseName: String, medication: MedicationItem)]] = [:]

        for course in activeCourses {
            let startDay = calendar.startOfDay(for: course.startDate)
            let endDay = calendar.startOfDay(for: course.endDate)

            for med in course.medications {
                var currentDate = startDay
                while currentDate <= endDay {
                    if currentDate >= today && currentDate <= maxDate {
                        for time in med.timesOfDay {
                            let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
                            if let triggerDate = calendar.date(bySettingHour: timeComponents.hour ?? 0, minute: timeComponents.minute ?? 0, second: 0, of: currentDate), triggerDate > now {

                                // Skip slots already marked as taken, so a dose logged in
                                // advance doesn't still trigger a reminder.
                                let alreadyTaken = med.logs.contains { log in
                                    log.isTaken &&
                                    calendar.isDate(log.scheduledTime, inSameDayAs: triggerDate) &&
                                    calendar.component(.hour, from: log.scheduledTime) == calendar.component(.hour, from: triggerDate) &&
                                    calendar.component(.minute, from: log.scheduledTime) == calendar.component(.minute, from: triggerDate)
                                }

                                if !alreadyTaken {
                                    scheduleMap[triggerDate, default: []].append((courseName: course.name, medication: med))
                                }
                            }
                        }
                    }
                    if currentDate > maxDate { break }
                    currentDate = calendar.date(byAdding: .day, value: med.frequencyDays, to: currentDate) ?? endDay.addingTimeInterval(1)
                }
            }
        }

        return scheduleMap
    }

    // MARK: - Scheduling

    func scheduleNotifications(activeCourses: [TreatmentCourse]) {
        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current

        let scheduleMap = Self.buildScheduleMap(activeCourses: activeCourses, now: Date(), calendar: calendar)

        // Sort by trigger date so that, if the count exceeds iOS's 60-notification
        // limit, it's the soonest reminders that get scheduled rather than an
        // arbitrary Dictionary iteration order.
        let sortedEntries = scheduleMap.sorted { $0.key < $1.key }

        var scheduledCount = 0
        for (triggerDate, medsAtTime) in sortedEntries {
            guard scheduledCount < 60 else { break } // iOS limit

            let content = UNMutableNotificationContent()

            // e.g. "Omega-3, Vitamin D"
            let medicationNames = medsAtTime.map { $0.medication.name }.joined(separator: ", ")
            let medicationIds = medsAtTime.map { $0.medication.id.uuidString }

            content.title = "💊 Время приема"
            content.body = "Пора принять: \(medicationNames)"
            content.sound = .default
            content.categoryIdentifier = "PILL_REMINDER_CATEGORY"

            content.userInfo = [
                "medicationIds": medicationIds,
                "time": triggerDate.timeIntervalSince1970
            ]

            let triggerComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)

            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            center.add(request) { error in
                if let error = error { print("🚨 Error: \(error)") }
            }
            scheduledCount += 1
        }
        print("🔔 Grouped and scheduled notifications: \(scheduledCount)")
    }

    // MARK: - Snooze

    func scheduleSnooze(for medicationIds: [String], combinedNames: String) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()

        content.title = "Напоминание (Snooze)"
        content.body = "Вы откладывали: \(combinedNames)"
        content.sound = .default
        content.categoryIdentifier = "PILL_REMINDER_CATEGORY"

        let triggerDate = Date().addingTimeInterval(Self.snoozeInterval)
        content.userInfo = [
            "medicationIds": medicationIds,
            "time": triggerDate.timeIntervalSince1970
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Self.snoozeInterval, repeats: false)
        // Joined IDs form a unique identifier for this group snooze.
        let uniqueIdentifier = "SNOOZE_\(medicationIds.joined(separator: "_"))"

        let request = UNNotificationRequest(identifier: uniqueIdentifier, content: content, trigger: trigger)
        center.add(request) { error in
            if let error = error { print("🚨 Snooze error: \(error)") }
        }
    }

    // MARK: - Cancellation

    func cancelNotifications(for medicationId: UUID) {
        let center = UNUserNotificationCenter.current()
        let targetIdString = medicationId.uuidString

        // 1. Remove already-delivered notifications (from the lock screen)
        center.getDeliveredNotifications { notifications in
            let deliveredToRemove = notifications.compactMap { notif -> String? in
                if let reqMedIds = notif.request.content.userInfo["medicationIds"] as? [String],
                   reqMedIds.contains(targetIdString) {
                    return notif.request.identifier
                }
                return nil
            }
            if !deliveredToRemove.isEmpty {
                center.removeDeliveredNotifications(withIdentifiers: deliveredToRemove)
                print("🧹 Removed from lock screen: \(deliveredToRemove.count)")
            }
        }

        // 2. Cancel future (pending) notifications for this medication
        center.getPendingNotificationRequests { requests in
            let pendingToRemove = requests.compactMap { request -> String? in
                if let reqMedIds = request.content.userInfo["medicationIds"] as? [String],
                   reqMedIds.contains(targetIdString) {
                    return request.identifier
                }
                return nil
            }
            if !pendingToRemove.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: pendingToRemove)
                print("🗑 Cancelled pending notifications: \(pendingToRemove.count)")
            }
        }

        center.removePendingNotificationRequests(withIdentifiers: ["SNOOZE_\(targetIdString)"])
    }
}
