//
//  WidgetSnapshotPeriodTitle.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import SwiftUI
import WidgetKit

extension WidgetSnapshot.Period {
    /// The keys DayPeriod uses in the app.
    var title: LocalizedStringKey {
        switch self {
        case .morning: "Morning"
        case .afternoon: "Afternoon"
        case .evening: "Evening"
        }
    }
}
