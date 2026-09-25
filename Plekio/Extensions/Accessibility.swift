//
//  Accessibility.swift
//  Plekio
//

import SwiftUI

// MARK: - Touch targets

extension View {

    /// Grows a control's touch target to the 44 pt HIG minimum WITHOUT moving
    /// the control or its neighbours.
    ///
    /// SwiftUI hit-tests a `Button` against its label, not against padding put
    /// around it — which is why several icon buttons here were tappable only
    /// across the glyph itself. Padding alone would fix the hit area but push
    /// the layout apart, so the space is given back afterwards: `.contentShape`
    /// claims the grown frame as the hit region, and the negative padding
    /// restores the footprint the control reports to its parent. The glyph
    /// keeps its size and position; the tappable area reaches into the
    /// surrounding whitespace.
    ///
    /// The expansion must stay inside the nearest clipping ancestor (a card's
    /// `.cornerRadius`, a `.clipped()`): touches outside a clip are dropped.
    /// Every call site here expands into its own card's padding.
    func expandTouchTarget(_ inset: CGFloat) -> some View {
        padding(inset)
            .contentShape(Rectangle())
            .padding(-inset)
    }

    /// Asymmetric variant, for controls that are already wide enough in one
    /// axis or that sit close enough to a neighbour that expanding both sides
    /// would overlap its hit area.
    func expandTouchTarget(vertical: CGFloat, horizontal: CGFloat) -> some View {
        padding(.vertical, vertical)
            .padding(.horizontal, horizontal)
            .contentShape(Rectangle())
            .padding(.vertical, -vertical)
            .padding(.horizontal, -horizontal)
    }
}

// MARK: - Dynamic Type

/// A system font at a chosen point size that still follows Dynamic Type.
///
/// `.font(.system(size:))` is frozen — it ignores the text-size setting
/// entirely. Switching to a text style (`.system(.largeTitle, design: .serif)`)
/// scales, but replaces the size the screen was composed around with Apple's
/// own (34 pt where the design says 36). `@ScaledMetric` keeps the design's
/// size at the default setting and scales it along the chosen style's curve
/// from there, which is what makes this swap invisible until someone actually
/// changes their text size.
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

    /// - Parameter style: the text style whose scaling curve to follow. Pick the
    ///   one nearest the size in points, so headings grow like headings and
    ///   captions like captions.
    func scaledFont(
        size: CGFloat,
        relativeTo style: Font.TextStyle,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> some View {
        modifier(ScaledFont(size: size, relativeTo: style, weight: weight, design: design))
    }
}
