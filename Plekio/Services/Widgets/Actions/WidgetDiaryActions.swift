//
//  WidgetDiaryActions.swift
//  Plekio
//
//  Created by Edward Gasparian on 22.10.2026.
//

import AppIntents

@MainActor
enum WidgetDiaryActions {

    /// Logs the mood as the diary's Today card would, then rewrites the snapshot so
    /// the widget redraws with the check-in. A store that can't be opened drops it:
    /// unlike a dose, a missed mood tap is no reason for an alert.
    static func logMood(_ raw: String) async {
        guard let mood = DiaryMood(rawValue: raw),
              let dependencies = AppDelegate.shared?.launcher.dependencies,
              dependencies.quickMoodLogging.log(mood) else { return }
        await dependencies.widgetSnapshots.refresh().value
    }
}
