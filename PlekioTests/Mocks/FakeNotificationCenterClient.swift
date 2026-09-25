//
//  FakeNotificationCenterClient.swift
//  PlekioTests
//
//  An in-memory notification centre. Keeps real UNNotificationRequests, so what
//  NotificationService builds is what the tests read back.
//
//  It yields where the real centre makes a round trip — reading the queue,
//  adding, clearing — because those are the points where two unserialised
//  rebuilds would interleave. A fake that never suspended could not show the
//  bug the service's queue exists to prevent.
//

import Foundation
import UserNotifications
@testable import Plekio

@MainActor
final class FakeNotificationCenterClient: NotificationCenterClient {

    var pending: [UNNotificationRequest] = []
    var delivered: [UNNotificationRequest] = []
    private(set) var registeredCategories: Set<UNNotificationCategory> = []

    var grantsAuthorization = true
    var authorizationError: Error?

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
}
