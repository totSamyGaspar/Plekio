//
//  WidgetSnapshotPublisherTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 21.10.2026.
//

import Testing
import Foundation
import Combine
@testable import Plekio

@MainActor
@Suite("WidgetSnapshotPublisher")
struct WidgetSnapshotPublisherTests {

    // MARK: - Helpers

    private let now = testDate(2026, 10, 21, 9)
    private let db = MockDatabaseService()
    private let reloader = SpyWidgetReloader()
    private let store = WidgetSnapshotStore(
        url: FileManager.default.temporaryDirectory.appending(path: "widget-publisher-\(UUID().uuidString).json")
    )

    private var today: Date { Calendar.current.startOfDay(for: now) }

    private func pill(_ name: String, at time: Date, status: DoseStatus = .pending) -> PillDose {
        PillDose(medicationId: UUID(), name: name, dosage: 1, form: .pill, time: time, period: .morning, status: status)
    }

    private func makePublisher(
        store: WidgetSnapshotStore?,
        changes: AnyPublisher<Void, Never> = Empty().eraseToAnyPublisher()
    ) -> WidgetSnapshotPublisher {
        WidgetSnapshotPublisher(
            doses: db,
            courses: SwiftDataCourseRepository(store: db),
            store: store,
            reloader: reloader,
            changes: changes,
            time: FixedTime(now)
        )
    }

    // MARK: - Writing

    @Test("A refresh writes today's and tomorrow's slots and reloads the widgets once")
    func refreshWritesTodayAndTomorrow() async {
        defer { try? store.clear() }
        let morning = testDate(2026, 10, 21, 8)
        let tomorrow = testDate(2026, 10, 22, 8)
        db.pillsByDay = [
            today: [pill("Sertraline", at: morning, status: .taken(at: morning, dispensed: 1))],
            addingDays(1, to: today): [pill("Sertraline", at: tomorrow)],
            addingDays(2, to: today): [pill("Sertraline", at: testDate(2026, 10, 23, 8))]
        ]

        // Held: the refresh keeps only a weak reference, as AppDependencies owns it in the app.
        let publisher = makePublisher(store: store)
        await publisher.refresh().value

        let snapshot = store.read()
        #expect(snapshot?.slots.map(\.time) == [morning, tomorrow])
        #expect(snapshot?.slots.first?.doses.first?.status == .taken)
        #expect(snapshot?.generatedAt == now)
        #expect(reloader.reloadCount == 1)
    }

    @Test("The streak in the snapshot is the one Today shows")
    func refreshCountsStreak() async {
        defer { try? store.clear() }
        let yesterday = addingDays(-1, to: today)
        db.pillsByDay = [
            yesterday: [pill("Sertraline", at: yesterday.addingTimeInterval(8 * 3600), status: .taken(at: yesterday, dispensed: 1))]
        ]

        // Held: the refresh keeps only a weak reference, as AppDependencies owns it in the app.
        let publisher = makePublisher(store: store)
        await publisher.refresh().value

        #expect(store.read()?.streakDays == 1)
    }

    @Test("An unchanged schedule is neither rewritten nor reloaded")
    func unchangedSnapshotIsSkipped() async {
        defer { try? store.clear() }
        db.pillsByDay = [today: [pill("Sertraline", at: testDate(2026, 10, 21, 8))]]
        let publisher = makePublisher(store: store)

        await publisher.refresh().value
        await publisher.refresh().value

        #expect(reloader.reloadCount == 1)
    }

    @Test("A logged dose is written and reloads the widgets again")
    func changedDoseReloads() async {
        defer { try? store.clear() }
        let morning = testDate(2026, 10, 21, 8)
        let id = UUID()
        db.pillsByDay = [today: [PillDose(medicationId: id, name: "Sertraline", dosage: 1, form: .pill, time: morning, period: .morning)]]
        let publisher = makePublisher(store: store)
        await publisher.refresh().value

        db.pillsByDay = [today: [PillDose(medicationId: id, name: "Sertraline", dosage: 1, form: .pill, time: morning,
                                          period: .morning, status: .taken(at: now, dispensed: 1))]]
        await publisher.refresh().value

        #expect(reloader.reloadCount == 2)
        #expect(store.read()?.slots.first?.doses.first?.status == .taken)
    }

    @Test("After erasing, the snapshot is empty: no medication names are left behind")
    func emptyScheduleWritesEmptySnapshot() async {
        defer { try? store.clear() }
        db.pillsByDay = [today: [pill("Sertraline", at: testDate(2026, 10, 21, 8))]]
        let publisher = makePublisher(store: store)
        await publisher.refresh().value

        db.pillsByDay = [:]
        await publisher.refresh().value

        #expect(store.read()?.slots.isEmpty == true)
        #expect(reloader.reloadCount == 2)
    }

    // MARK: - Triggers

    @Test("A store write announced by the feed refreshes the snapshot")
    func changeTriggersRefresh() async {
        defer { try? store.clear() }
        let changes = PassthroughSubject<Void, Never>()
        let publisher = makePublisher(store: store, changes: changes.eraseToAnyPublisher())
        #expect(publisher.lastRefresh == nil)

        changes.send()
        await publisher.lastRefresh?.value

        #expect(store.read() != nil)
        #expect(reloader.reloadCount == 1)
    }

    @Test("Without a store nothing is written or reloaded, as in previews")
    func noStoreDoesNothing() async {
        let publisher = makePublisher(store: nil)

        await publisher.refresh().value

        #expect(publisher.lastRefresh == nil)
        #expect(reloader.reloadCount == 0)
    }
}
