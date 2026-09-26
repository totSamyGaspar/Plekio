//
//  NotificationServiceTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Testing
import Foundation
import UserNotifications
@testable import Plekio

@MainActor
@Suite("NotificationService", .serialized)
struct NotificationServiceTests {

    // MARK: - Helpers

    private let calendar = Calendar.current

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2030, month: 6, day: day, hour: hour, minute: minute))!
    }

    /// Service over the fake centre with isolated settings; clock pinned to 10 June 2030, 08:00 by default.
    private func makeService(
        _ center: FakeNotificationCenterClient,
        now: Date? = nil
    ) -> (NotificationService, UserDefaults, String) {
        let suite = "PlekioTests.NotificationService.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let service = NotificationService(
            center: center,
            settings: SettingsStore(defaults: defaults),
            time: FixedTime(now ?? date(10, 8))
        )
        return (service, defaults, suite)
    }

    /// One medication at 09:00 every day, 10–12 June.
    private func database() -> MockDatabaseService {
        let db = MockDatabaseService()
        let course = TreatmentCourse(name: "Курс", startDate: date(10, 0), endDate: date(12, 0))
        let nineOClock = calendar.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: 9))!
        course.medications.append(
            MedicationItem(id: UUID(), name: "Ибупрофен", formSystemImage: "pills.fill",
                           dosage: 1, timesOfDay: [nineOClock], frequencyDays: 1)
        )
        db.coursesToReturn = [course]
        return db
    }

    private func slotRequest(_ identifier: String, ids: [String], at slot: Date) -> UNNotificationRequest {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: slot)
        return ReminderRequestFactory.doseReminder(
            identifier: identifier,
            medicationIds: ids,
            medicationNames: ids.map { _ in "Лекарство" },
            triggerDate: slot,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
    }

    // MARK: - Rebuilds

    @Test("пересборка кладёт в очередь напоминание на каждый будущий слот")
    func rebuildQueuesEveryFutureSlot() async {
        let center = FakeNotificationCenterClient()
        let (service, defaults, suite) = makeService(center)
        defer { defaults.removePersistentDomain(forName: suite) }

        await service.rescheduleAll(using: database())

        #expect(center.pending.count == 3)
    }

    @Test("перекрывающиеся пересборки не удваивают напоминания")
    func overlappingRebuildsDoNotDuplicate() async {
        // Interleaved rebuilds would let B's clear land between A's clear and adds.
        let center = FakeNotificationCenterClient()
        let (service, defaults, suite) = makeService(center)
        defer { defaults.removePersistentDomain(forName: suite) }
        let db = database()

        await service.rescheduleAll(using: db)
        let single = center.pending.count

        async let first: Void = service.rescheduleAll(using: db)
        async let second: Void = service.rescheduleAll(using: db)
        async let third: Void = service.rescheduleAll(using: db)
        _ = await (first, second, third)

        #expect(single > 0)
        #expect(center.pending.count == single)
    }

    @Test("отмена лекарства во время пересборки не оставляет дублей")
    func cancellationQueuedWithARebuildLeavesNoDuplicates() async {
        let center = FakeNotificationCenterClient()
        let (service, defaults, suite) = makeService(center)
        defer { defaults.removePersistentDomain(forName: suite) }
        let db = database()
        await service.rescheduleAll(using: db)
        let single = center.pending.count

        async let rebuild: Void = service.rescheduleAll(using: db)
        async let cancel: Void = service.cancelNotifications(for: UUID())
        _ = await (rebuild, cancel)

        #expect(center.pending.count == single)
    }

    // MARK: - Cancellation

    @Test("удалённое лекарство уходит из общего напоминания и с экрана блокировки")
    func cancellationRegroupsAndClearsDelivered() async {
        let center = FakeNotificationCenterClient()
        let (service, defaults, suite) = makeService(center)
        defer { defaults.removePersistentDomain(forName: suite) }

        let deleted = UUID()
        let kept = UUID().uuidString
        center.pending = [slotRequest("GROUP", ids: [deleted.uuidString, kept], at: date(11, 9))]
        center.delivered = [slotRequest("SHOWN", ids: [deleted.uuidString], at: date(10, 9))]

        await service.cancelNotifications(for: deleted)

        // Rebuilt under the same identifier, naming only what is left.
        #expect(center.pending.map(\.identifier) == ["GROUP"])
        #expect(ReminderSnapshot(request: center.pending[0]).medicationIds == [kept])
        #expect(center.delivered.isEmpty)
    }

    // MARK: - Delivered cleanup

    @Test("баннер снимается, только когда закрыт весь слот")
    func deliveredBannerLeavesOnlyWhenTheSlotIsSettled() async {
        let center = FakeNotificationCenterClient()
        let (service, defaults, suite) = makeService(center)
        defer { defaults.removePersistentDomain(forName: suite) }

        let a = UUID(), b = UUID()
        let slot = date(10, 9)
        center.delivered = [slotRequest("SHOWN", ids: [a.uuidString, b.uuidString], at: slot)]

        await service.clearDelivered(settledMedicationIds: [a], scheduledTime: slot)
        #expect(center.delivered.count == 1)

        await service.clearDelivered(settledMedicationIds: [a, b], scheduledTime: slot)
        #expect(center.delivered.isEmpty)
    }

    // MARK: - Daily reminders

    @Test("новый список времён заменяет старый целиком")
    func dailyReminderTimesReplaceTheOldOnes() async {
        let center = FakeNotificationCenterClient()
        let (service, defaults, suite) = makeService(center)
        defer { defaults.removePersistentDomain(forName: suite) }

        await service.scheduleDailyReminder(.bloodPressure, minutesOfDay: [9 * 60, 13 * 60, 20 * 60])
        await service.scheduleDailyReminder(.bloodPressure, minutesOfDay: [9 * 60])

        let ids = Set(DailyReminder.bloodPressure.allRequestIdentifiers)
        #expect(center.pending.filter { ids.contains($0.identifier) }.count == 1)
    }

    @Test("пересборка возвращает включённые ежедневные напоминания")
    func rebuildRestoresEnabledDailyReminders() async {
        let center = FakeNotificationCenterClient()
        let (service, defaults, suite) = makeService(center)
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: DailyReminder.diary.enabledKey)

        await service.rescheduleAll(using: MockDatabaseService())

        // A rebuild's clear also removes daily reminders, so it must re-add them.
        #expect(center.pending.contains { DailyReminder.diary.allRequestIdentifiers.contains($0.identifier) })
    }

    // MARK: - Permission and setup

    @Test("отказ и ошибка разрешения — false, а не исключение")
    func permissionDenialAndErrorAreFalse() async {
        let center = FakeNotificationCenterClient()
        let (service, defaults, suite) = makeService(center)
        defer { defaults.removePersistentDomain(forName: suite) }

        center.grantsAuthorization = false
        #expect(await service.requestPermission() == false)

        center.authorizationError = NSError(domain: "test", code: 1)
        #expect(await service.requestPermission() == false)
    }

    @Test("категории с кнопками регистрируются при создании сервиса")
    func categoriesAreRegisteredOnInit() {
        let center = FakeNotificationCenterClient()
        let (_, defaults, suite) = makeService(center)
        defer { defaults.removePersistentDomain(forName: suite) }

        // requestPermission may never run on later launches; actions must still exist.
        #expect(!center.registeredCategories.isEmpty)
    }

    // MARK: - Snooze

    @Test("отложенное напоминание несёт время дозы, и «Принять» по нему находит её")
    func snoozeCarriesTheDoseSlot() async throws {
        let center = FakeNotificationCenterClient()
        let (service, defaults, suite) = makeService(center)
        defer { defaults.removePersistentDomain(forName: suite) }
        let id = UUID()
        let slot = date(10, 9)

        await service.scheduleSnooze(for: [id.uuidString], names: ["Ибупрофен"], slot: slot)

        let request = try #require(center.pending.first)
        #expect(ReminderRequestFactory.isSnooze(request.identifier))
        let intent = NotificationIntent.parse(
            userInfo: request.content.userInfo,
            actionIdentifier: NotificationAction.take
        )
        #expect(intent == .take(medicationIds: [id], slot: slot))
    }

    @Test("пересборка сохраняет отложенное напоминание, пока доза не отмечена")
    func rebuildKeepsSnoozeOfAnOpenDose() async throws {
        let center = FakeNotificationCenterClient()
        let (service, defaults, suite) = makeService(center)
        defer { defaults.removePersistentDomain(forName: suite) }
        let db = database()
        let med = try #require(db.coursesToReturn.first?.medications.first)

        await service.scheduleSnooze(for: [med.id.uuidString], names: [med.name], slot: date(10, 9))
        await service.rescheduleAll(using: db)

        #expect(center.pending.contains { ReminderRequestFactory.isSnooze($0.identifier) })
    }

    @Test("пересборка снимает отложенное напоминание, если дозу уже приняли")
    func rebuildDropsSnoozeOfATakenDose() async throws {
        let center = FakeNotificationCenterClient()
        let (service, defaults, suite) = makeService(center)
        defer { defaults.removePersistentDomain(forName: suite) }
        let db = database()
        let med = try #require(db.coursesToReturn.first?.medications.first)
        let slot = date(10, 9)

        await service.scheduleSnooze(for: [med.id.uuidString], names: [med.name], slot: slot)
        let log = DoseLog(scheduledTime: slot, status: .taken(at: slot, dispensed: 1))
        log.medication = med
        med.logs.append(log)
        await service.rescheduleAll(using: db)

        #expect(!center.pending.contains { ReminderRequestFactory.isSnooze($0.identifier) })
    }

    @Test("отложенные напоминания разных слотов не затирают друг друга")
    func snoozesOfDifferentSlotsCoexist() async {
        let center = FakeNotificationCenterClient()
        let (service, defaults, suite) = makeService(center)
        defer { defaults.removePersistentDomain(forName: suite) }
        let id = UUID().uuidString

        await service.scheduleSnooze(for: [id], names: ["Ибупрофен"], slot: date(10, 9))
        await service.scheduleSnooze(for: [id], names: ["Ибупрофен"], slot: date(10, 21))

        #expect(center.pending.filter { ReminderRequestFactory.isSnooze($0.identifier) }.count == 2)
    }

    // MARK: - Badge

    @Test("каждое напоминание ставит на иконку число открытых к этому времени доз дня")
    func eachReminderCarriesTheOpenCountAtItsTime() async throws {
        let center = FakeNotificationCenterClient()
        let (service, defaults, suite) = makeService(center)
        defer { defaults.removePersistentDomain(forName: suite) }
        let db = database()
        let course = try #require(db.coursesToReturn.first)
        let onePM = calendar.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: 13))!
        course.medications.append(
            MedicationItem(id: UUID(), name: "Витамин D", formSystemImage: "pills.fill",
                           dosage: 1, timesOfDay: [onePM], frequencyDays: 1)
        )

        await service.rescheduleAll(using: db)

        let badges = Dictionary(uniqueKeysWithValues: center.pending.compactMap { request -> (Date, Int)? in
            guard let slot = ReminderPayload.slotTime(in: request.content.userInfo) else { return nil }
            return (Date(timeIntervalSince1970: slot), request.content.badge?.intValue ?? -1)
        })
        #expect(badges[date(10, 9)] == 1)
        #expect(badges[date(10, 13)] == 2)
        #expect(badges[date(11, 9)] == 1)
    }

    @Test("пересборка ставит на иконку число доз, время которых пришло")
    func rebuildSetsTheLiveBadge() async {
        let center = FakeNotificationCenterClient()
        let (service, defaults, suite) = makeService(center, now: date(10, 10))
        defer { defaults.removePersistentDomain(forName: suite) }

        await service.rescheduleAll(using: database())

        #expect(center.badgeCount == 1)
    }

    @Test("принятая доза уходит с иконки")
    func takenDoseLeavesTheBadge() async throws {
        let center = FakeNotificationCenterClient()
        let (service, defaults, suite) = makeService(center, now: date(10, 10))
        defer { defaults.removePersistentDomain(forName: suite) }
        let db = database()
        let med = try #require(db.coursesToReturn.first?.medications.first)
        let log = DoseLog(scheduledTime: date(10, 9), status: .taken(at: date(10, 9), dispensed: 1))
        log.medication = med
        med.logs.append(log)

        await service.rescheduleAll(using: db)

        #expect(center.badgeCount == 0)
    }

    // MARK: - Refill

    @Test("пересборка ставит одно напоминание о запасе, пока лекарство на исходе")
    func rebuildQueuesRefillWhileLow() async throws {
        let center = FakeNotificationCenterClient()
        let (service, defaults, suite) = makeService(center)
        defer { defaults.removePersistentDomain(forName: suite) }
        let db = database()
        let med = try #require(db.coursesToReturn.first?.medications.first)
        med.stockCount = 3

        await service.rescheduleAll(using: db)
        await service.rescheduleAll(using: db)

        #expect(center.pending.filter { $0.identifier == RefillReminder.identifier }.count == 1)
    }

    @Test("при достаточном запасе напоминания о пополнении нет")
    func noRefillWhenStocked() async {
        let center = FakeNotificationCenterClient()
        let (service, defaults, suite) = makeService(center)
        defer { defaults.removePersistentDomain(forName: suite) }

        await service.rescheduleAll(using: database())

        #expect(!center.pending.contains { $0.identifier == RefillReminder.identifier })
    }
}
