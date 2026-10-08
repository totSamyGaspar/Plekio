//
//  CoursePreview.swift
//  Plekio
//
//  Created by Edward Gasparian on 22.09.2026.
//

import SwiftUI

/// Onboarding slide 1: a course being set up, animated start to finish.
struct CoursePreview: View {

    // MARK: - Properties

    var isActive = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var now = Frame.opening
    @State private var touch = TouchPhase.none

    private static let name = "Ibuprofen"
    private static let times = ["08:00", "14:00", "20:00"]

    /// All animated state in one value, so opening and finished frames can be named.
    private struct Frame {
        var typed = 0
        var isEditing = false
        var detailsShown = false
        var times = 0
        var isAddShown = true
        var pack = 0

        static let opening = Frame()
        static let finished = Frame(
            typed: CoursePreview.name.count,
            detailsShown: true,
            times: CoursePreview.times.count,
            isAddShown: false,
            pack: 30
        )
    }

    /// With Reduce Motion on, the slide is the finished card and nothing moves.
    private var shown: Frame { reduceMotion ? .finished : now }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            divider
            intakeTimes
            divider
            pack
        }
        .frame(width: 306)
        .onboardingCard(18, radius: 26)
        .task(id: isActive) {
            guard isActive, !reduceMotion else { return }
            await Demo.loop(scene) { now = .opening; touch = .none }
        }
    }

    // MARK: - Scene

    private func scene() async throws {
        try await Demo.wait(0.5)
        now.isEditing = true

        for count in 1...Self.name.count {
            try await Demo.wait(0.075)
            now.typed = count
        }

        try await Demo.wait(0.35)
        withAnimation(.snappy(duration: 0.4)) {
            now.isEditing = false
            now.detailsShown = true
        }

        try await Demo.wait(0.6)
        for count in 1...Self.times.count {
            try await Demo.tap($touch) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) { now.times = count }
            }
            try await Demo.wait(0.1)
        }

        withAnimation(.easeOut(duration: 0.3)) { now.isAddShown = false }
        try await Demo.wait(0.25)
        withAnimation(.snappy(duration: 0.7)) { now.pack = 30 }

        try await Demo.wait(2.8)
        withAnimation(.easeInOut(duration: 0.45)) { now = .opening }
        try await Demo.wait(0.5)
    }

    // MARK: - Subviews

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "pills.fill")
                .font(.system(size: 18))
                .foregroundColor(.accentPrimary)
                .frame(width: 44, height: 44)
                .background(Color.accentPrimary.opacity(0.14))
                .clipShape(.rect(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 1) {
                    Text(verbatim: String(Self.name.prefix(shown.typed)))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.textPrimary)

                    // Solid caret: iOS doesn't blink it while typing.
                    Capsule()
                        .fill(Color.accentPrimary)
                        .frame(width: 2, height: 19)
                        .opacity(shown.isEditing ? 1 : 0)
                }
                .frame(height: 22)

                Text("Every day")
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
                    .opacity(shown.detailsShown ? 1 : 0)
                    .offset(y: shown.detailsShown ? 0 : 5)
            }

            Spacer(minLength: 0)

            Text(verbatim: "2")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.accentPrimary)
                .opacity(shown.detailsShown ? 1 : 0)
                .scaleEffect(shown.detailsShown ? 1 : 0.4)
        }
    }

    private var intakeTimes: some View {
        VStack(alignment: .leading, spacing: 9) {
            OnboardingCaption(text: "Intake Time")

            HStack(spacing: 7) {
                ForEach(Self.times.prefix(shown.times), id: \.self) { time in
                    Text(verbatim: time)
                        .font(.system(size: 13))
                        .monospacedDigit()
                        .foregroundColor(.textPrimary)
                        .onboardingChip()
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                }

                if shown.isAddShown {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.accentPrimary)
                        .frame(width: 34, height: 27)
                        .background(Color.accentPrimary.opacity(0.14))
                        .clipShape(.capsule)
                        .demoTouch(touch, pressScale: 0.88)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
            }
            .frame(height: 27, alignment: .leading)
        }
    }

    private var pack: some View {
        HStack {
            Text("Left in pack")
                .font(.system(size: 13))
                .foregroundColor(.textSecondary)
            Spacer(minLength: 0)
            Text(verbatim: "\(shown.pack)")
                .font(.system(size: 14, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(.textPrimary)
                .contentTransition(.numericText(value: Double(shown.pack)))
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.textPrimary.opacity(0.08))
            .frame(height: 1)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    CoursePreview()
        .padding(40)
        .background(Color.appBackground)
}
#endif
