//
//  Accessibility.swift
//  Plekio
//
//  Created by Edward Gasparian on 29.08.2026.
//

import SwiftUI

// MARK: - Touch targets

extension View {

    /// Grows the hit area by `inset` without changing layout.
    /// Must stay inside the nearest clipping ancestor: touches outside a clip are dropped.
    func expandTouchTarget(_ inset: CGFloat) -> some View {
        padding(inset)
            .contentShape(Rectangle())
            .padding(-inset)
    }

    /// Asymmetric variant, for when expanding both axes would overlap a neighbour.
    func expandTouchTarget(vertical: CGFloat, horizontal: CGFloat) -> some View {
        padding(.vertical, vertical)
            .padding(.horizontal, horizontal)
            .contentShape(Rectangle())
            .padding(.vertical, -vertical)
            .padding(.horizontal, -horizontal)
    }
}

// MARK: - Dynamic Type

/// A fixed design point size that still scales with Dynamic Type
/// (`.system(size:)` alone does not scale).
private struct ScaledFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight
    private let design: Font.Design

    init(size: CGFloat, relativeTo style: Font.TextStyle, weight: Font.Weight, design: Font.Design) {
        self._size = ScaledMetric(wrappedValue: size, relativeTo: style)
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight, design: design))
    }
}

extension View {

    /// - Parameter style: text style whose scaling curve to follow; pick the one nearest `size`.
    func scaledFont(
        size: CGFloat,
        relativeTo style: Font.TextStyle,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> some View {
        modifier(ScaledFont(size: size, relativeTo: style, weight: weight, design: design))
    }
}
