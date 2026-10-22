//
//  BloodPressureWidget.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 22.10.2026.
//

import SwiftUI
import WidgetKit

// MARK: - BloodPressureWidget

struct BloodPressureWidget: Widget {
    static let kind = "BloodPressure"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: DoseTimelineProvider()) { entry in
            BloodPressureWidgetView(entry: entry)
        }
        .configurationDisplayName("Blood Pressure")
        .description("Your latest reading and its trend.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
