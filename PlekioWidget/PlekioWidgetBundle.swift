//
//  PlekioWidgetBundle.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import SwiftUI
import WidgetKit

/// Every widget reads the snapshot the app writes; none opens the store.
@main
struct PlekioWidgetBundle: WidgetBundle {
    var body: some Widget {
        UpNextWidget()
        DayProgressWidget()
        TodayWidget()
        LowStockWidget()
    }
}
