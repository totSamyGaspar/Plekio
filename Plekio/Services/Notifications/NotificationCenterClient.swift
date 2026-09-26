//
//  NotificationCenterClient.swift
//  Plekio
//
//  Created by Edward Gasparian on 14.09.2026.
//

import Foundation
import OSLog
import UserNotifications

/// The notification centre reduced to what the app uses; a seam for tests.
@MainActor
protocol NotificationCenterClient {

    func setCategories(_ categories: Set<UNNotificationCategory>)

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool

    func pendingReminders() async -> [ReminderSnapshot]
    func deliveredReminders() async -> [ReminderSnapshot]

    func add(_ request: UNNotificationRequest) async throws

    func removePending(identifiers: [String])
    func removeDelivered(identifiers: [String])

    /// Clears every pending request; returns only once the removal has actually happened.
    func removeAllPending() async

    func setBadgeCount(_ count: Int) async
}

// MARK: - SystemNotificationCenterClient

/// The real notification centre.
@MainActor
struct SystemNotificationCenterClient: NotificationCenterClient {

    private var center: UNUserNotificationCenter { .current() }

    func setCategories(_ categories: Set<UNNotificationCategory>) {
        center.setNotificationCategories(categories)
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await center.requestAuthorization(options: options)
    }

    func pendingReminders() async -> [ReminderSnapshot] {
        await center.pendingNotificationRequests().map(ReminderSnapshot.init(request:))
    }

    func deliveredReminders() async -> [ReminderSnapshot] {
        await center.deliveredNotifications().map { ReminderSnapshot(request: $0.request) }
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }

    func removePending(identifiers: [String]) {
        guard !identifiers.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func removeDelivered(identifiers: [String]) {
        guard !identifiers.isEmpty else { return }
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func removeAllPending() async {
        center.removeAllPendingNotificationRequests()

        // The removal is async; the centre runs calls in order, so this read waits for it.
        // Scheduling while it is in flight would wipe the rebuild that follows.
        _ = await center.pendingNotificationRequests()
    }

    func setBadgeCount(_ count: Int) async {
        do {
            try await center.setBadgeCount(count)
        } catch {
            AppLog.notifications.error("Badge update failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
