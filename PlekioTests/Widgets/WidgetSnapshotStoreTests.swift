//
//  WidgetSnapshotStoreTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 21.10.2026.
//

import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("WidgetSnapshotStore")
struct WidgetSnapshotStoreTests {

    // MARK: - Helpers

    private let store = WidgetSnapshotStore(
        url: FileManager.default.temporaryDirectory.appending(path: "widget-snapshot-\(UUID().uuidString).json")
    )

    private let snapshot = WidgetSnapshot(
        generatedAt: Date(timeIntervalSince1970: 1_800_000_000.25),
        missedGrace: 3600,
        slots: [
            WidgetSnapshot.Slot(
                time: Date(timeIntervalSince1970: 1_800_003_600),
                period: .evening,
                doses: [WidgetSnapshot.Dose(medicationId: UUID(), name: "Omega-3", dosage: 2, form: .capsule, status: .skipped)]
            )
        ],
        streakDays: 12,
        lowStock: [WidgetSnapshot.StockAlert(medicationId: UUID(), name: "Sertraline", stock: 4, threshold: 10)]
    )

    // MARK: - Tests

    @Test("A written snapshot reads back unchanged, down to the slot's exact time")
    func roundTrip() throws {
        try store.write(snapshot)
        defer { try? store.clear() }
        #expect(store.read() == snapshot)
    }

    @Test("No file reads as nothing, not as an empty day")
    func missingFileIsNil() {
        #expect(store.read() == nil)
    }

    @Test("A snapshot from another version reads as nothing")
    func otherVersionIsNil() throws {
        var newer = snapshot
        newer.version = WidgetSnapshot.currentVersion + 1
        try store.write(newer)
        defer { try? store.clear() }
        #expect(store.read() == nil)
    }

    @Test("A broken file reads as nothing")
    func corruptFileIsNil() throws {
        try Data("{not json".utf8).write(to: store.url)
        defer { try? store.clear() }
        #expect(store.read() == nil)
    }

    @Test("A form a newer app added reads as a pill instead of failing the snapshot")
    func unknownFormFallsBackToPill() throws {
        try store.write(snapshot)
        defer { try? store.clear() }
        let text = try String(contentsOf: store.url, encoding: .utf8)
            .replacingOccurrences(of: "\"capsule\"", with: "\"inhaler\"")
        try Data(text.utf8).write(to: store.url)

        #expect(store.read()?.slots.first?.doses.first?.form == .pill)
    }

    @Test("Clearing removes the file, and clearing twice is fine")
    func clearRemovesFile() throws {
        try store.write(snapshot)
        try store.clear()
        #expect(store.read() == nil)
        try store.clear()
    }

    @Test("The snapshot sits beside the store, in the app's folder")
    func locationPutsSnapshotBesideStore() {
        let location = StorageLocation(root: FileManager.default.temporaryDirectory.appending(path: "PlekioWidgetLocation"))
        #expect(location.widgetSnapshotURL.deletingLastPathComponent() == location.storeURL.deletingLastPathComponent())
    }
}
