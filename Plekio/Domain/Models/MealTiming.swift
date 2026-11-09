//
//  MealTiming.swift
//  Plekio
//
//  Created by Edward Gasparian on 09.11.2026.
//

import Foundation

/// When a medication is taken relative to food. No value means it doesn't matter.
/// Raw values are stored: never rename them.
nonisolated enum MealTiming: String, CaseIterable, Sendable {
    case beforeMeal, withMeal, afterMeal, emptyStomach

    var title: LocalizedStringResource {
        switch self {
        case .beforeMeal: "Before meals"
        case .withMeal: "With meals"
        case .afterMeal: "After meals"
        case .emptyStomach: "Empty stomach"
        }
    }

    static let systemImage = "fork.knife"
}
