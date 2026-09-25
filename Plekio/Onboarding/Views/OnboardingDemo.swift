//
//  OnboardingDemo.swift
//  Plekio
//

import SwiftUI

/// The pieces every slide's little film is made of.
///
/// A slide does not shimmer or float: it plays the thirty seconds of use its
/// two lines promise. A finger lands, the control answers the way the real one
/// does, and the result follows. Someone who never touches the screen still
/// sees what a tap does before the app asks them for one.

/// Where the demonstrated finger is in its tap.
enum TouchPhase: Equatable {
    case none, hover, press, lift
}

/// The touch mark, as screen recordings draw it: a soft disc that settles on
/// the control, sinks on press and leaves a ring behind as it lifts.
struct TouchIndicator: View {

    let phase: TouchPhase

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.accentPrimary, lineWidth: 2)
                .scaleEffect(phase == .lift ? 2.1 : 1)
                .opacity(phase == .press ? 0.45 : 0)

            Circle()
                .fill(Color.textPrimary.opacity(0.16))
                .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 1.5))
                .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
                .scaleEffect(discScale)
                .opacity(discOpacity)
        }
        .frame(width: 42, height: 42)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var discScale: CGFloat {
        switch phase {
        case .none: 1.6
        case .hover: 1
        case .press: 0.8
        case .lift: 1.15
        }
    }

    private var discOpacity: Double {
        switch phase {
        case .hover, .press: 1
        case .none, .lift: 0
        }
    }
}

extension View {

    /// Puts the finger on this control and lets it give way under the press,
    /// the way a real button does.
    func demoTouch(_ phase: TouchPhase, pressScale: CGFloat = 0.96) -> some View {
        self
            .scaleEffect(phase == .press ? pressScale : 1)
            .overlay { TouchIndicator(phase: phase) }
    }
}

/// Timing for the scripts. Each slide's scene is a plain `async` function that
/// sets state step by step; cancelling its task — the slide leaving the screen
/// — is what stops it.
enum Demo {

    static func wait(_ seconds: Double) async throws {
        try await Task.sleep(for: .seconds(seconds))
    }

    /// One tap. `action` runs as the finger lifts, which is when a real button
    /// fires, and should animate its own change.
    static func tap(_ phase: Binding<TouchPhase>, action: () -> Void) async throws {
        try await press(phase, holding: 0.16, action: action)
    }

    /// A long press: the finger stays down for `holding`, `action` runs while
    /// it is still there — the way a held notification opens under the thumb —
    /// and then it lifts.
    static func press(_ phase: Binding<TouchPhase>, holding: Double, action: () -> Void) async throws {
        withAnimation(.easeOut(duration: 0.28)) { phase.wrappedValue = .hover }
        try await wait(0.38)
        withAnimation(.easeOut(duration: 0.1)) { phase.wrappedValue = .press }
        try await wait(holding)
        action()
        withAnimation(.easeOut(duration: 0.45)) { phase.wrappedValue = .lift }
        try await wait(0.45)
        instantly { phase.wrappedValue = .none }
    }

    /// A change the viewer must not see happen.
    static func instantly(_ change: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, change)
    }

    /// Plays `scene` over and over until the task is cancelled, then puts the
    /// slide back on its opening frame, off screen, ready for the next visit.
    static func loop(_ scene: () async throws -> Void, rewind: () -> Void) async {
        do {
            while true { try await scene() }
        } catch {}
        instantly(rewind)
    }
}
