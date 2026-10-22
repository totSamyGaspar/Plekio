//
//  TodayWidget.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import SwiftUI
import WidgetKit
import AppIntents

// MARK: - TodayWidget

struct TodayWidget: Widget {
    static let kind = "Today"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: DoseTimelineProvider()) { entry in
            TodayView(entry: entry)
        }
        .configurationDisplayName("Today")
        .description("Every dose of the day, morning to evening.")
        .supportedFamilies([.systemLarge])
        // The up-next card runs to the widget's edges; TodayView pads the rest itself.
        .contentMarginsDisabled()
    }
}
