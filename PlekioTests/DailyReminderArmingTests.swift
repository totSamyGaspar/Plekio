//
//  DailyReminderArmingTests.swift
//  PlekioTests
//
//  Switching a daily reminder on and off — above all, what happens when the
//  user has not allowed notifications.
//

import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("DailyReminderArming")
struct DailyReminderArmingTests {

    @Test("включение с разрешением ставит напоминание в очередь")
    func enablingWithPermissionArms() async {
        let notifications = MockNotificationService()
        let arming = DailyReminderArming(notifications: notifications)

        let result = await arming.apply(.diary, enabled: true, minutesOfDay: [21 * 60])

        #expect(result == .armed)
        #expect(notifications.scheduledReminders[.diary] == [21 * 60])
    }

    @Test("отказ в разрешении — явный результат, а не тихий выход")
    func deniedPermissionIsReported() async {
        // The regression: this path returned quietly, the switch stayed on, and
        // the Settings screen claimed a reminder that could never fire.
        let notifications = MockNotificationService()
        notifications.permissionGranted = false
        let arming = DailyReminderArming(notifications: notifications)

        let result = await arming.apply(.bloodPressure, enabled: true, minutesOfDay: [9 * 60])

        #expect(result == .permissionDenied)
        #expect(notifications.scheduledReminders[.bloodPressure] == nil)
        // Nothing half-armed left behind from an earlier "on".
        #expect(notifications.cancelledReminders == [.bloodPressure])
    }

    @Test("выключение снимает напоминание и разрешения не спрашивает")
    func disablingCancelsWithoutAsking() async {
        let notifications = MockNotificationService()
        let arming = DailyReminderArming(notifications: notifications)

        let result = await arming.apply(.diary, enabled: false, minutesOfDay: [21 * 60])

        #expect(result == .disarmed)
        #expect(notifications.cancelledReminders == [.diary])
        #expect(notifications.didCallRequestPermission == false)
    }
}
