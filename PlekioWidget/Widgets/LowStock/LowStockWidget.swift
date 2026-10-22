//
//  LowStockWidget.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import SwiftUI
import WidgetKit

struct LowStockWidget: Widget {
    static let kind = "LowStock"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: DoseTimelineProvider()) { entry in
            LowStockView(entry: entry)
        }
        .configurationDisplayName("Low stock")
        .description("Medications that are running out.")
        .supportedFamilies([.systemSmall])
    }
}
