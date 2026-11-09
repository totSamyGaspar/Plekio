//
//  WidgetMealTiming.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 09.11.2026.
//

import SwiftUI

extension WidgetSnapshot.Dose {

    /// Nil when it doesn't matter, or for a value from a newer app this widget doesn't know.
    var mealTimingTitle: LocalizedStringKey? {
        switch mealTiming {
        case "beforeMeal": "Before meals"
        case "withMeal": "With meals"
        case "afterMeal": "After meals"
        case "emptyStomach": "Empty stomach"
        default: nil
        }
    }

    static let mealTimingImage = "fork.knife"
}
