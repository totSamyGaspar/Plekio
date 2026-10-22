//
//  DiaryWidget.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 22.10.2026.
//

import SwiftUI
import WidgetKit
import AppIntents

// MARK: - DiaryWidget

struct DiaryWidget: Widget {
    static let kind = "Diary"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: DoseTimelineProvider()) { entry in
            DiaryWidgetView(entry: entry)
        }
        .configurationDisplayName("Diary")
        .description("Log your mood in one tap.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
