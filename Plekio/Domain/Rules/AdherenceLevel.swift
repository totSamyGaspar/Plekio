//
//  AdherenceLevel.swift
//  Plekio
//
//  Created by Edward Gasparian on 19.11.2026.
//

import Foundation

/// How the weekly average reads on the adherence badge.
nonisolated enum AdherenceLevel: Equatable, CaseIterable {
    case optimal
    case couldBeBetter
    case needsAttention

    static let optimalFrom = 90
    static let couldBeBetterFrom = 70

    init(percent: Int) {
        switch percent {
        case Self.optimalFrom...:       self = .optimal
        case Self.couldBeBetterFrom...: self = .couldBeBetter
        default:                        self = .needsAttention
        }
    }
}
