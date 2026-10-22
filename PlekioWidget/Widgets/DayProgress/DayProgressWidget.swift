//
//  DayProgressWidget.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import SwiftUI
import WidgetKit

struct DayProgressWidget: Widget {
    static let kind = "DayProgress"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: DoseTimelineProvider()) { entry in
            DayProgressView(entry: entry)
        }
        .configurationDisplayName("Day progress")
        .description("How much of today's plan is logged.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}
