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

    @Test("An awaited refresh still writes when another starts behind it")
    func awaitedRefreshIsNotCancelled() async {
        defer { try? store.clear() }
        db.pillsByDay = [today: [pill("Sertraline", at: testDate(2026, 10, 21, 8))]]
        let publisher = makePublisher(store: store)

        // As after a widget button: the button awaits one, the write's feed starts another.
        let awaited = publisher.refresh()
        publisher.refresh()
        await awaited.value

        #expect(store.read() != nil)
        await publisher.lastRefresh?.value
        #expect(reloader.reloadCount == 1)
    }

    @Test("Today's check-in reaches the snapshot; yesterday's doesn't")
    func diaryReachesTheSnapshot() async {
        defer { try? store.clear() }
        func entry(_ date: Date, mood: DiaryMood) -> DiaryEntry {
            DiaryEntry(checkInDate: date, moodLabel: mood.rawValue, moodScore: mood.score, physicalSummary: "",
                       energyLevel: 3, discomfortLevel: 0, sleepHours: 7, sleepQuality: SleepQuality.good.rawValue,
                       waterGlasses: 6, symptoms: [], reflectionNotes: "", milestoneTags: [], photoIds: [],
                       isQuickLog: false)
        }
        db.diaryEntriesToReturn = [entry(testDate(2026, 10, 20, 21), mood: .great)]
        let publisher = WidgetSnapshotPublisher(
            doses: db,
            courses: SwiftDataCourseRepository(store: db),
            diary: SwiftDataDiaryRepository(store: db),
            store: store,
            reloader: reloader,
            changes: Empty().eraseToAnyPublisher(),
            time: FixedTime(now)
        )

        await publisher.refresh().value
        #expect(store.read()?.diary == nil)

        db.diaryEntriesToReturn.append(entry(testDate(2026, 10, 21, 8), mood: .stressed))
        await publisher.refresh().value
        #expect(store.read()?.diary?.mood == .stressed)
    }

    // MARK: - Widget Buttons

    @Test("publishNow writes a logged dose at once, without awaiting a refresh")
    func publishNowWritesTheDose() async {
        defer { try? store.clear() }
        let morning = testDate(2026, 10, 21, 8)
        let id = UUID()
        db.pillsByDay = [today: [PillDose(medicationId: id, name: "Sertraline", dosage: 1, form: .pill, time: morning, period: .morning)]]
        let publisher = makePublisher(store: store)
        await publisher.refresh().value

        db.pillsByDay = [today: [PillDose(medicationId: id, name: "Sertraline", dosage: 1, form: .pill, time: morning,
                                          period: .morning, status: .taken(at: now, dispensed: 1))]]
        publisher.publishNow()

        #expect(store.read()?.slots.first?.doses.first?.status == .taken)
        #expect(reloader.reloadCount == 2)
    }

    @Test("publishNow adds today to the streak of the days before")
    func publishNowCountsToday() async {
        defer { try? store.clear() }
        let yesterday = addingDays(-1, to: today)
        let morning = testDate(2026, 10, 21, 8)
        let id = UUID()
        db.pillsByDay = [
            yesterday: [pill("Sertraline", at: yesterday.addingTimeInterval(8 * 3600), status: .taken(at: yesterday, dispensed: 1))],
            today: [PillDose(medicationId: id, name: "Sertraline", dosage: 1, form: .pill, time: morning, period: .morning)]
        ]
        let publisher = makePublisher(store: store)
        await publisher.refresh().value
        #expect(store.read()?.streakDays == 1)

        db.pillsByDay[today] = [PillDose(medicationId: id, name: "Sertraline", dosage: 1, form: .pill, time: morning,
                                         period: .morning, status: .taken(at: now, dispensed: 1))]
        publisher.publishNow()
        #expect(store.read()?.streakDays == 2)

        // Taken back: today no longer counts, the days before still do.
        db.pillsByDay[today] = [PillDose(medicationId: id, name: "Sertraline", dosage: 1, form: .pill, time: morning, period: .morning)]
        publisher.publishNow()
        #expect(store.read()?.streakDays == 1)
    }

    @Test("Before any refresh, publishNow keeps the streak already on disk")
    func publishNowKeepsTheStreakOnDisk() throws {
        defer { try? store.clear() }
        var onDisk = WidgetSnapshot.empty(at: now, missedGrace: 3600)
        onDisk.streakDays = 5
        try store.write(onDisk)
        db.pillsByDay = [today: [pill("Sertraline", at: testDate(2026, 10, 21, 8), status: .taken(at: now, dispensed: 1))]]

        // As on a launch woken by the widget: no history has been read yet.
        let publisher = makePublisher(store: store)
        publisher.publishNow()

        #expect(store.read()?.streakDays == 5)
        #expect(store.read()?.slots.first?.doses.first?.status == .taken)
    }

    @Test("Without a store publishNow does nothing, as in previews")
    func publishNowWithoutStore() {
        let publisher = makePublisher(store: nil)
        publisher.publishNow()
        #expect(reloader.reloadCount == 0)
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
