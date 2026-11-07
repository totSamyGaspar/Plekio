//
//  UpNextWidget.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import SwiftUI
import WidgetKit
import AppIntents

struct UpNextWidget: Widget {
    static let kind = "UpNext"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: DoseTimelineProvider()) { entry in
            UpNextView(entry: entry)
        }
        .configurationDisplayName("Up next")
        .description("Your next doses, ready to log.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}
