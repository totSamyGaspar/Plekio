//
//  DoseTimelineProvider.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import WidgetKit

/// Reads the snapshot the app writes; never the store, which may be mid-migration.
/// The app reloads the widgets after each change; between changes the timeline
/// carries the widget through the day on its own.
struct DoseTimelineProvider: TimelineProvider {

    /// Well under what WidgetKit keeps: two days of slots, grace ends and midnights.
    private static let maxEntries = 60

    /// Built on use: `appGroup()` traps on a missing App Group, a signing error.
    private var store: WidgetSnapshotStore { WidgetSnapshotStore(location: .appGroup()) }

    func placeholder(in context: Context) -> DoseEntry {
        DoseEntry(date: .now, snapshot: .sample(at: .now))
    }

    /// The gallery gets sample doses: real medication names don't belong in it.
    func getSnapshot(in context: Context, completion: @escaping (DoseEntry) -> ()) {
        let now = Date.now
        let snapshot: WidgetSnapshot? = context.isPreview ? WidgetSnapshot.sample(at: now) : store.read()
        completion(DoseEntry(date: now, snapshot: snapshot))
    }

    /// An entry now and at every moment the widget changes without new data.
    /// After the last one WidgetKit asks again, which also picks up a snapshot
    /// written while the widget wasn't listening.
    func getTimeline(in context: Context, completion: @escaping (Timeline<DoseEntry>) -> ()) {
        let now = Date.now
        let calendar = Calendar.autoupdatingCurrent
        let snapshot = store.read()

        let changes = snapshot?.changeDates(after: now, calendar: calendar)
            ?? [calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now.addingTimeInterval(86_400)]
        let dates = [now] + changes.prefix(Self.maxEntries - 1)

        completion(Timeline(entries: dates.map { DoseEntry(date: $0, snapshot: snapshot) }, policy: .atEnd))
    }
}
