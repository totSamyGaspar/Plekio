//
//  NotificationResponseHandlerTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("Notification responses")
struct NotificationResponseHandlerTests {

    // MARK: - Helpers

    private let slot = Date(timeIntervalSince1970: 1_780_000_000)

    private func payload(_ ids: [UUID], names: [String] = ["Ибупрофен"]) -> [AnyHashable: Any] {
        ReminderPayload.userInfo(
            medicationIds: ids.map(\.uuidString),
            medicationNames: names,
            triggerDate: slot
        )
    }

    private func dose(_ id: UUID) -> PillDose {
        PillDose(medicationId: id, name: "Ибупрофен", dosage: 1,
                 formSystemImage: "pills.fill", time: slot, period: .morning)
    }

    @MainActor
    private struct Harness {
        let db = MockDatabaseService()
        let notifications = MockNotificationService()
        let router = AppRouter()
        let errors = SpyErrorReporter()

        var handler: NotificationResponseHandler {
            NotificationResponseHandler(
                doseLogging: DoseLoggingUseCase(dbService: db, notificationService: notifications),
                notifications: notifications,
                router: router,
                errors: errors
            )
        }
    }

    // MARK: - Parsing

    @Test("каждая кнопка напоминания о дозе разбирается в своё намерение")
    func parsesEachDoseAction() {
        let id = UUID()
        let info = payload([id])

        #expect(NotificationIntent.parse(userInfo: info, actionIdentifier: NotificationAction.take)
                == .take(medicationIds: [id], slot: slot))
        #expect(NotificationIntent.parse(userInfo: info, actionIdentifier: NotificationAction.skip)
                == .skip(medicationIds: [id], slot: slot))
        #expect(NotificationIntent.parse(userInfo: info, actionIdentifier: NotificationAction.snooze)
                == .snooze(medicationIds: [id.uuidString], names: ["Ибупрофен"], slot: slot))
        // A plain tap on the body carries the system's default identifier.
        #expect(NotificationIntent.parse(userInfo: info, actionIdentifier: "com.apple.UNNotificationDefaultActionIdentifier")
                == .openDoseReminder(medicationIds: [id], slot: slot))
    }

    @Test("ежедневное напоминание узнаётся раньше, чем проверка на id лекарств")
    func parsesDailyReminderWithoutMedicationIds() {
        let info: [AnyHashable: Any] = [DailyReminder.userInfoKey: DailyReminder.bloodPressure.rawValue]

        #expect(NotificationIntent.parse(userInfo: info, actionIdentifier: "any")
                == .openDailyReminder(.bloodPressure))
    }

    @Test("напоминание без лекарств или без времени игнорируется")
    func dropsMalformedPayloads() {
        let noIds = ReminderPayload.userInfo(medicationIds: [], medicationNames: [], triggerDate: slot)
        let noTime: [AnyHashable: Any] = [ReminderPayload.medicationIdsKey: [UUID().uuidString]]

        #expect(NotificationIntent.parse(userInfo: noIds, actionIdentifier: NotificationAction.take) == nil)
        #expect(NotificationIntent.parse(userInfo: noTime, actionIdentifier: NotificationAction.take) == nil)
        #expect(NotificationIntent.parse(userInfo: [:], actionIdentifier: NotificationAction.take) == nil)
    }

    // MARK: - Handling

    @Test("«Принять» записывает дозу, дожидается перепланировки и открывает «Сегодня»")
    func takeLogsAndWaitsForReminders() async {
        let h = Harness()
        let id = UUID()
        h.db.pillsToReturn = [dose(id)]
        h.router.selectedTab = .diary

        await h.handler.handle(.take(medicationIds: [id], slot: slot))

        #expect(h.db.pillsToReturn.first?.isTaken == true)
        // The rebuild is awaited inside handle, before the completion handler would run.
        #expect(h.notifications.scheduleCallCount == 1)
        #expect(h.router.selectedTab == .today)
        #expect(h.router.pendingDeepLink == nil)
    }

    @Test("повторное «Принять» ничего не пишет")
    func takeTwiceWritesOnce() async {
        let h = Harness()
        let id = UUID()
        h.db.pillsToReturn = [dose(id)]

        await h.handler.handle(.take(medicationIds: [id], slot: slot))
        await h.handler.handle(.take(medicationIds: [id], slot: slot))

        #expect(h.db.markedTakenSlots.count == 1)
    }

    @Test("«Пропустить» записывает пропуск, а не просто закрывает баннер")
    func skipRecordsTheSkip() async {
        let h = Harness()
        let id = UUID()
        h.db.pillsToReturn = [dose(id)]

        await h.handler.handle(.skip(medicationIds: [id], slot: slot))

        #expect(h.db.pillsToReturn.first?.isSkipped == true)
        #expect(h.notifications.scheduleCallCount == 1)
    }

    @Test("«Отложить» ставит повтор и ничего не пишет в базу")
    func snoozeSchedulesOnly() async {
        let h = Harness()
        let id = UUID().uuidString

        await h.handler.handle(.snooze(medicationIds: [id], names: ["Ибупрофен"], slot: slot))

        #expect(h.notifications.snoozedMedicationIds == [id])
        #expect(h.notifications.snoozedSlot == slot)
        #expect(h.db.markedTakenSlots.isEmpty)
        #expect(h.db.skippedSlots.isEmpty)
    }

    @Test("тап по напоминанию открывает окно дозы через роутер")
    func tapOpensTheDoseModal() async {
        let h = Harness()
        let id = UUID()

        await h.handler.handle(.openDoseReminder(medicationIds: [id], slot: slot))

        #expect(h.router.pendingDeepLink == .doseReminder(medicationIds: [id], slot: slot))
        #expect(h.db.markedTakenSlots.isEmpty)
    }

    @Test("тап по ежедневному напоминанию ведёт в дневник")
    func dailyReminderOpensDiary() async {
        let h = Harness()

        await h.handler.handle(.openDailyReminder(.diary))

        #expect(h.router.selectedTab == .diary)
        #expect(h.router.pendingDeepLink == .dailyReminder(.diary))
    }

    @Test("ошибка записи уходит в ErrorReporting, перепланировки нет")
    func failedWriteIsReported() async {
        let h = Harness()
        let id = UUID()
        h.db.pillsToReturn = [dose(id)]
        h.db.markTakenError = NSError(domain: "test", code: 1)

        await h.handler.handle(.take(medicationIds: [id], slot: slot))

        #expect(h.errors.reported.count == 1)
        #expect(h.notifications.scheduleCallCount == 0)
    }
}
