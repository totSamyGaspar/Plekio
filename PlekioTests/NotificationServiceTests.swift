//
//  NotificationServiceTests.swift
//  PlekioTests
//
//  NotificationService against an in-memory centre. The planner and the plans
//  it makes are tested on their own (ReminderPlannerTests); these check that the
//  service carries them out — and, above all, that overlapping rebuilds cannot
//  leave every reminder in the queue twice.
//

import Testing
import Foundation
import UserNotifications
@testable import Plekio

@MainActor
@Suite("NotificationService", .serialized)
struct NotificationServiceTests {

    private let calendar = Calendar.current

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2030, month: 6, day: day, hour: hour, minute: minute))!
    }

    /// A service over the fake centre, with settings of its own and the clock
    /// pinned to 10 June 2030, 08:00.
    private func makeService(_ center: FakeNotificationCenterClient) -> (NotificationService, UserDefaults, String) {
        let suite = "PlekioTests.NotificationService.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let service = NotificationService(
            center: center,
            settings: SettingsStore(defaults: defaults),
            time: FixedTime(date(10, 8))
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
        // THE regression the service's queue exists for. Every rebuild is a
        // Task started from a write, so two overlapping is the normal case; left
        // to interleave, B's clear lands between A's clear and A's adds, and
        // both sets survive — every reminder twice.
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

        // Dropping from three times to one must take the other two with it, or
        // they keep firing at times the user removed.
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

        // They share the queue with the dose reminders, so a rebuild's clear
        // takes them down — and the rebuild must put them back.
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

        // Not only inside requestPermission: on a second launch that path may
        // never run, and reminders would arrive without Take / Snooze / Skip.
        #expect(!center.registeredCategories.isEmpty)
    }
}
