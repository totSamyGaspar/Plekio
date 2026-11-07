//
//  WidgetSnapshotMoodTitle.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 22.10.2026.
//

import SwiftUI
import WidgetKit
import AppIntents

extension WidgetSnapshot.Mood {
    /// The keys DiaryMood uses in the app.
    var title: LocalizedStringKey {
        switch self {
        case .great: "Great"
        case .good: "Good"
        case .neutral: "Neutral"
        case .downLow: "Down / Low"
        case .stressed: "Stressed"
        case .exhausted: "Exhausted"
        case .inPain: "In Pain"
        }
    }
}
