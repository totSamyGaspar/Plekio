//
//  DayPreview.swift
//  Plekio
//

import SwiftUI

/// Slide 2: the day split into morning, afternoon and evening.
///
/// The list scrolls down past the doses already taken, a finger logs the one
/// that is due, and the highlight moves on to the evening. Then the same tap
/// takes it back — the second half of the slide's sentence — and the list
/// returns to the top.
///
/// The logged rows are dimmed rather than removed: the point of the slide is
/// that the day is one list you move down, not a queue that empties.
struct DayPreview: View {

    var isActive = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var now = Frame.opening
    @State private var touch = TouchPhase.none

    private struct Frame {
        var scroll: CGFloat = 0
        var isIbuprofenLogged = false

        static let opening = Frame()
        /// Scrolled to the dose that is due, so the still slide shows it.
        static let still = Frame(scroll: Self.scrolled)
        static let scrolled: CGFloat = 100
    }

    private var shown: Frame { reduceMotion ? .still : now }

    private enum RowState { case logged, next, waiting }

    var body: some View {
        list
            .fixedSize(horizontal: false, vertical: true)
            .offset(y: -shown.scroll)
            .frame(width: 306, height: 250, alignment: .top)
            // Rows fade out at the edges instead of being cut, the way a list
            // looks under a navigation bar.
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.08),
                        .init(color: .black, location: 0.9),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .task(id: isActive) {
                guard isActive, !reduceMotion else { return }
                await Demo.loop(scene) { now = .opening; touch = .none }
            }
    }

    // MARK: - Scene

    private func scene() async throws {
        try await Demo.wait(0.7)
        withAnimation(.smooth(duration: 1.1)) { now.scroll = Frame.scrolled }

        try await Demo.wait(1.3)
        try await Demo.tap($touch) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { now.isIbuprofenLogged = true }
        }

        try await Demo.wait(1.5)
        try await Demo.tap($touch) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { now.isIbuprofenLogged = false }
        }

        try await Demo.wait(0.9)
        withAnimation(.smooth(duration: 1.0)) { now.scroll = 0 }
        try await Demo.wait(1.5)
    }

    // MARK: - UI Components

    private var list: some View {
        let logged = shown.isIbuprofenLogged

        return VStack(spacing: 10) {
            section(title: "Morning", tally: "2 / 2", isDone: true)
            row(time: "08:00", name: "Bisoprolol", state: .logged)
            row(time: "08:00", name: "Aspirin", state: .logged)

            section(title: "Afternoon", tally: logged ? "1 / 1" : "0 / 1", isDone: logged)
                .padding(.top, 6)
            row(time: "14:00", name: "Ibuprofen", state: logged ? .logged : .next, touch: touch)

            section(title: "Evening", tally: "0 / 2", isDone: false)
                .padding(.top, 6)
            row(time: "20:00", name: "Bisoprolol", state: logged ? .next : .waiting)
            row(time: "21:30", name: "Magnesium", state: .waiting)
        }
    }

    private func section(title: LocalizedStringResource, tally: String, isDone: Bool) -> some View {
        HStack {
            OnboardingCaption(text: title)
            Spacer(minLength: 0)
            Text(verbatim: tally)
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(isDone ? .accentPrimary : .textSecondary)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 4)
    }

    private func row(time: String, name: String, state: RowState, touch: TouchPhase = .none) -> some View {
        HStack(spacing: 12) {
            // Sized to its text: a fixed width cut "08:00" to "08:…" in the
            // serif, whose zero is wider than its one.
            Text(verbatim: time)
                .font(.system(size: 16, weight: .bold, design: .serif))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
                .foregroundColor(state == .next ? .accentPrimary : .textPrimary)
                .frame(minWidth: 50, alignment: .leading)

            Text(verbatim: name)
                .font(.system(size: 15, weight: state == .next ? .semibold : .regular))
                .foregroundColor(.textPrimary)

            Spacer(minLength: 0)

            check(state)
                .demoTouch(touch, pressScale: 0.82)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(Color.appSurface)
        .clipShape(.rect(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.accentPrimary.opacity(state == .next ? 0.4 : 0), lineWidth: 1)
        )
        .opacity(state == .logged ? 0.45 : 1)
        .scaleEffect(touch == .press ? 0.98 : 1)
    }

    /// One view for all three states rather than three views, so logging a
    /// dose fills the ring it is in instead of swapping it for another.
    private func check(_ state: RowState) -> some View {
        let isLogged = state == .logged

        return ZStack {
            Circle()
                .stroke(state == .waiting ? Color.textPrimary.opacity(0.18) : Color.accentPrimary, lineWidth: 2)

            Circle()
                .fill(Color.accentPrimary)
                .scaleEffect(isLogged ? 1 : 0.01)

            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(.onAccent)
                .scaleEffect(isLogged ? 1 : 0.3)
                .opacity(isLogged ? 1 : 0)
        }
        .frame(width: 26, height: 26)
    }
}

#Preview {
    DayPreview()
        .padding(40)
        .background(Color.appBackground)
}
