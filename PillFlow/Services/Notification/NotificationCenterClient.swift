//
//  NotificationCenterClient.swift
//  PillFlow
//

import Foundation
import OSLog
import UserNotifications

/// The notification centre, reduced to what this app asks of it.
///
/// Exists so the rules above it can be tested. `UNUserNotificationCenter` is a
/// system singleton whose reads return `UNNotification` values that cannot be
/// constructed, so anything that talked to it directly could only be exercised on
/// a device — which meant cancellation, regrouping and delivered cleanup were
/// never tested at all.
@MainActor
protocol NotificationCenterClient {

    func setCategories(_ categories: Set<UNNotificationCategory>)

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool

    func pendingReminders() async -> [ReminderSnapshot]
    func deliveredReminders() async -> [ReminderSnapshot]

    func add(_ request: UNNotificationRequest) async throws

    func removePending(identifiers: [String])
    func removeDelivered(identifiers: [String])

    /// Clears every pending request and does not return until the centre has
    /// actually carried it out.
    func removeAllPending() async
}

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

        // `removeAllPendingNotificationRequests()` is asynchronous: it returns at
        // once and the removal happens later, on the centre's own queue. The centre
        // handles calls in order, so a read issued after the removal only comes
        // back once the removal is done — which is all this read is for.
        //
        // Everything downstream depends on it: scheduling on top of a removal that
        // is still in flight wipes the rebuild that follows it.
        _ = await center.pendingNotificationRequests()
    }
}
