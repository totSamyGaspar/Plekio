//
//  WidgetSnapshotBuilderTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 21.10.2026.
//

import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("WidgetSnapshotBuilder")
struct WidgetSnapshotBuilderTests {

    // MARK: - Helpers

    private func pill(_ name: String, at time: Date, period: DayPeriod = .morning,
                      form: MedicationForm = .pill, status: DoseStatus = .pending) -> PillDose {
        PillDose(medicationId: UUID(), name: name, dosage: 1, form: form, time: time, period: period, status: status)
    }

    private func medication(_ name: String, stock: Int) -> MedicationSnapshot {
        MedicationSnapshot(id: UUID(), name: name, form: .pill, dosage: 1, minutesOfDay: [480],
                           frequencyDays: 1, stockCount: stock, lowStockThreshold: 10)
    }

    // MARK: - Slots

    @Test("Doses at one time form one slot; slots are in time order, doses by name")
    func groupsBySlot() {
        let morning = testDate(2026, 10, 21, 8)
        let evening = testDate(2026, 10, 21, 20)
        let slots = WidgetSnapshotBuilder.slots(from: [
            pill("Omega-3", at: evening, period: .evening),
            pill("Vitamin D", at: morning),
            pill("Magnesium", at: evening, period: .evening),
            pill("Sertraline", at: morning)
        ])

        #expect(slots.map(\.time) == [morning, evening])
        #expect(slots[0].doses.map(\.name) == ["Sertraline", "Vitamin D"])
        #expect(slots[1].doses.map(\.name) == ["Magnesium", "Omega-3"])
        #expect(slots[1].period == .evening)
    }

    @Test("Status and form carry over; the log time and stock dispensed stay in the app")
    func mapsStatusAndForm() {
        let time = testDate(2026, 10, 21, 8)
        let slots = WidgetSnapshotBuilder.slots(from: [
            pill("A", at: time, form: .drops, status: .taken(at: time, dispensed: 1)),
            pill("B", at: time, form: .injection, status: .skipped(at: time)),
            pill("C", at: time)
        ])

        #expect(slots[0].doses.map(\.status) == [.taken, .skipped, .pending])
        #expect(slots[0].doses.map(\.form) == [.drops, .injection, .pill])
    }

    @Test("Afternoon doses map to the widget's afternoon")
    func mapsNoonToAfternoon() {
        #expect(WidgetSnapshotBuilder.period(.noon) == .afternoon)
    }

    // MARK: - Snapshot

    @Test("The snapshot carries the grace, streak and lowest stock first")
    func buildsWholeSnapshot() {
        let now = testDate(2026, 10, 21, 9)
        let snapshot = WidgetSnapshotBuilder.build(
            pills: [pill("Sertraline", at: testDate(2026, 10, 21, 8))],
            streakDays: 5,
            lowStock: [medication("Magnesium", stock: 8), medication("Sertraline", stock: 4)],
            now: now
        )

        #expect(snapshot.generatedAt == now)
        #expect(snapshot.missedGrace == DoseSchedule.missedGrace)
        #expect(snapshot.streakDays == 5)
        #expect(snapshot.lowStock.map(\.name) == ["Sertraline", "Magnesium"])
        #expect(snapshot.version == WidgetSnapshot.currentVersion)
    }

    // MARK: - Diary and blood pressure

    @Test("Today's check-in carries its mood and whether it was a quick log")
    func mapsDiaryDay() {
        let entry = DiaryEntrySnapshot(
            id: UUID(), checkInDate: testDate(2026, 10, 21, 9), moodLabel: DiaryMood.downLow.rawValue,
            moodScore: 2, physicalSummary: "", energyLevel: 2, discomfortLevel: 0, sleepHours: 6.5,
            sleepQuality: SleepQuality.fair.rawValue, waterGlasses: 4, symptoms: [], reflectionNotes: "",
            milestoneTags: [], photoIds: [], isQuickLog: true
        )
        let day = WidgetSnapshotBuilder.diaryDay(entry)

        #expect(day.mood == .downLow)
        #expect(day.isQuickLog)
        #expect(day.sleepHours == 6.5)
        #expect(day.waterGlasses == 4)
    }

    @Test("Blood pressure keeps the latest seven readings, oldest first")
    func keepsLatestReadings() {
        let readings = (0..<10).map { index in
            BloodPressureSnapshot(id: UUID(), measuredAt: testDate(2026, 10, 10 + index, 8),
                                  systolic: 120 + index, diastolic: 80, pulse: index.isMultiple(of: 2) ? 70 : nil)
        }
        let snapshot = WidgetSnapshotBuilder.build(
            pills: [], streakDays: 0, lowStock: [], readings: readings.shuffled(), now: testDate(2026, 10, 21, 9)
        )

        #expect(snapshot.bloodPressure?.count == WidgetSnapshotBuilder.readingCount)
        #expect(snapshot.bloodPressure?.map(\.systolic) == Array(123...129))
        #expect(snapshot.latestReading?.systolic == 129)
    }

    @Test("A slot sent back from the widget finds the same doses in the store")
    func slotTimeMatchesOpenDoses() throws {
        let time = testDate(2026, 10, 21, 8)
        let pills = [pill("Sertraline", at: time)]
        let slot = try #require(WidgetSnapshotBuilder.slots(from: pills).first)
        // openDoses(medicationIds:at:) matches within one second.
        #expect(abs(slot.time.timeIntervalSince(pills[0].time)) < 1)
    }
}
