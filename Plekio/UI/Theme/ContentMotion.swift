//
//  ContentMotion.swift
//  Plekio
//
//  Created by Edward Gasparian on 26.09.2026.
//

import SwiftUI

// MARK: - View+ContentMotion

extension View {

    /// Rolls the digits of a number when `value` changes.
    func animatedNumber(_ value: Double) -> some View {
        modifier(AnimatedNumber(value: value))
    }

    /// Morphs an SF Symbol into its new name and bounces it when `trigger` changes.
    func animatedSymbol<Trigger: Equatable>(_ trigger: Trigger) -> some View {
        modifier(AnimatedSymbol(trigger: trigger))
    }
}

// MARK: - AnimatedNumber

private struct AnimatedNumber: ViewModifier {
    let value: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .contentTransition(reduceMotion ? .identity : .numericText(value: value))
            // Own animation: the change may arrive outside any animated transaction (e.g. a DB reload).
            .motion(.snappy, value: value)
    }
}

// MARK: - AnimatedSymbol

private struct AnimatedSymbol<Trigger: Equatable>: ViewModifier {
    let trigger: Trigger
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: trigger)
                .animation(.snappy, value: trigger)
        }
    }
}
