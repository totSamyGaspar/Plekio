//
//  FakeNotificationCenterClient.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Foundation
import UserNotifications
@testable import Plekio

@MainActor
final class FakeNotificationCenterClient: NotificationCenterClient {

    // MARK: - State

    var pending: [UNNotificationRequest] = []
    var delivered: [UNNotificationRequest] = []
    private(set) var registeredCategories: Set<UNNotificationCategory> = []
    private(set) var badgeCount: Int?

    var grantsAuthorization = true
    var authorizationError: Error?

    // MARK: - NotificationCenterClient

    func setCategories(_ categories: Set<UNNotificationCategory>) {
        registeredCategories = categories
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        if let authorizationError { throw authorizationError }
        return grantsAuthorization
    }

    func pendingReminders() async -> [ReminderSnapshot] {
        await Task.yield()
        return pending.map(ReminderSnapshot.init(request:))
    }

    func deliveredReminders() async -> [ReminderSnapshot] {
        await Task.yield()
        return delivered.map(ReminderSnapshot.init(request:))
    }

    func add(_ request: UNNotificationRequest) async throws {
        await Task.yield()
        // Same identifier replaces, as in the real centre.
        pending.removeAll { $0.identifier == request.identifier }
        pending.append(request)
    }

    func removePending(identifiers: [String]) {
        pending.removeAll { identifiers.contains($0.identifier) }
    }

    func removeDelivered(identifiers: [String]) {
        delivered.removeAll { identifiers.contains($0.identifier) }
    }

    func removeAllPending() async {
        pending.removeAll()
        await Task.yield()
    }

    func setBadgeCount(_ count: Int) async {
        badgeCount = count
    }
}
