//
//  Motion.swift
//  Plekio
//
//  Created by Edward Gasparian on 26.09.2026.
//

import SwiftUI

// MARK: - Motion

/// The app's animation curves. Use them through `motion(_:value:)` / `withMotion`,
/// which drop the movement when Reduce Motion is on.
enum Motion {
    /// Banners, toasts, overlays and selection changes.
    static let standard = Animation.spring(response: 0.35, dampingFraction: 0.85)
    /// Direct feedback on a tap: checkmarks, mood cards.
    static let bouncy = Animation.spring(response: 0.3, dampingFraction: 0.65)
    /// Progress rings, bars and lists settling after data changes.
    static let progress = Animation.spring(response: 0.7, dampingFraction: 0.78)
}

/// `withAnimation` that honours Reduce Motion.
@MainActor
func withMotion<Result>(_ animation: Animation = Motion.standard, _ body: () throws -> Result) rethrows -> Result {
    try withAnimation(UIAccessibility.isReduceMotionEnabled ? nil : animation, body)
}

// MARK: - View+Motion

extension View {

    /// `.animation(_:value:)` that honours Reduce Motion.
    func motion<Value: Equatable>(_ animation: Animation, value: Value) -> some View {
        modifier(MotionModifier(animation: animation, value: value))
    }

    /// A short scale pulse each time `isComplete` turns true. Nothing under Reduce Motion.
    func completionPulse(_ isComplete: Bool) -> some View {
        modifier(CompletionPulse(isComplete: isComplete))
    }
}

// MARK: - MotionModifier

private struct MotionModifier<Value: Equatable>: ViewModifier {
    let animation: Animation
    let value: Value
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

// MARK: - CompletionPulse

private struct CompletionPulse: ViewModifier {
    let isComplete: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Bumped only on the way to complete, so un-logging never pulses.
    @State private var completions = 0

    func body(content: Content) -> some View {
        content
            .keyframeAnimator(initialValue: 1.0, trigger: completions) { view, scale in
                view.scaleEffect(scale)
            } keyframes: { _ in
                KeyframeTrack {
                    SpringKeyframe(1.12, duration: 0.25)
                    SpringKeyframe(1.0, duration: 0.45)
                }
            }
            .onChange(of: isComplete) { _, done in
                if done && !reduceMotion { completions += 1 }
            }
    }
}
