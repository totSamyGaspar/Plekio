//
//  DailyReminderArmingTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("DailyReminderArming")
struct DailyReminderArmingTests {

    // MARK: - Arming

    @Test("Enabling with permission queues the reminder")
    func enablingWithPermissionArms() async {
        let notifications = MockNotificationService()
        let arming = DailyReminderArming(notifications: notifications)

        let result = await arming.apply(.diary, enabled: true, minutesOfDay: [21 * 60])

        #expect(result == .armed)
        #expect(notifications.scheduledReminders[.diary] == [21 * 60])
    }

    @Test("Permission denied is an explicit result, not a silent exit")
    func deniedPermissionIsReported() async {
        let notifications = MockNotificationService()
        notifications.permissionGranted = false
        let arming = DailyReminderArming(notifications: notifications)

        let result = await arming.apply(.bloodPressure, enabled: true, minutesOfDay: [9 * 60])

        #expect(result == .permissionDenied)
        #expect(notifications.scheduledReminders[.bloodPressure] == nil)
        // Nothing half-armed left behind from an earlier "on".
        #expect(notifications.cancelledReminders == [.bloodPressure])
    }

    // MARK: - Disarming

    @Test("Disabling removes the reminder and doesn't ask for permission")
    func disablingCancelsWithoutAsking() async {
        let notifications = MockNotificationService()
        let arming = DailyReminderArming(notifications: notifications)

        let result = await arming.apply(.diary, enabled: false, minutesOfDay: [21 * 60])

        #expect(result == .disarmed)
        #expect(notifications.cancelledReminders == [.diary])
        #expect(notifications.didCallRequestPermission == false)
    }
}
