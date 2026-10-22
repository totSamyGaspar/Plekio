//
//  Date+WidgetTime.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import SwiftUI
import WidgetKit

// MARK: - Formatting

extension Date {
    /// "08:00" / "8:00 AM", as the locale writes it.
    var widgetTime: Text {
        Text(self, format: .dateTime.hour().minute())
    }
}
