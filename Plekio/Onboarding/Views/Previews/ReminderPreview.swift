//
//  ReminderPreview.swift
//  Plekio
//

import SwiftUI

/// Slide 3: a dose reminder answered from the lock screen.
///
/// The clock turns to 14:00 and the reminder arrives. A finger holds it, the
/// lock screen dims and the system menu opens under it with the three actions
/// the category really carries — Take Now, Snooze, Skip. Take Now opens the
/// app on today's list with the dose already logged and the pack one lighter.
///
/// Every piece is what the phone actually shows: the banner's own text, the
/// menu's own titles, and the app opening afterwards, because Take Now is a
/// foreground action. A slide that promised more than the notification does
/// would be the first thing the user caught the app lying about.
struct ReminderPreview: View {

    var isActive = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var now = Frame.opening
    @State private var holdTouch = TouchPhase.none
    @State private var takeTouch = TouchPhase.none

    private static let medication = "Ibuprofen"

    private struct Frame {
        var isDue = false
        var isDelivered = false
        var isExpanded = false
        var isOpened = false
        var isLogged = false
        var left = 30
        var isVisible = true

        static let opening = Frame()
        /// The held reminder with its menu open: the one still frame that says
        /// what the slide says.
        static let still = Frame(isDue: true, isDelivered: true, isExpanded: true)
    }

    private var shown: Frame { reduceMotion ? .still : now }

    var body: some View {
        ZStack {
            lockScreen
                .opacity(shown.isOpened ? 0 : 1)
                .offset(y: shown.isOpened ? -24 : 0)

            if shown.isOpened {
                today
                    .transition(.offset(y: 30).combined(with: .opacity))
            }
        }
        .frame(width: 306)
        .opacity(shown.isVisible ? 1 : 0)
        .task(id: isActive) {
            guard isActive, !reduceMotion else { return }
            await Demo.loop(scene) {
                now = .opening
                holdTouch = .none
                takeTouch = .none
            }
        }
    }

    // MARK: - Scene

    private func scene() async throws {
        try await Demo.wait(0.8)
        withAnimation(.snappy(duration: 0.4)) { now.isDue = true }

        try await Demo.wait(0.45)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.76)) { now.isDelivered = true }

        try await Demo.wait(1.1)
        try await Demo.press($holdTouch, holding: 0.7) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { now.isExpanded = true }
        }

        try await Demo.wait(0.7)
        try await Demo.tap($takeTouch) {
            withAnimation(.easeInOut(duration: 0.45)) { now.isOpened = true }
        }

        try await Demo.wait(0.1)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { now.isLogged = true }
        try await Demo.wait(0.3)
        withAnimation(.snappy(duration: 0.5)) { now.left = 29 }

        // The clock does not run backwards on screen: the slide dips out,
        // resets and comes back for the next take.
        try await Demo.wait(2.4)
        withAnimation(.easeInOut(duration: 0.3)) { now.isVisible = false }
        try await Demo.wait(0.35)
        Demo.instantly { now = .opening; now.isVisible = false }
        withAnimation(.easeInOut(duration: 0.3)) { now.isVisible = true }
        try await Demo.wait(0.3)
    }

    // MARK: - Lock screen

    private var lockScreen: some View {
        VStack(spacing: 14) {
            Text(verbatim: shown.isDue ? "14:00" : "13:59")
                .font(.system(size: 52, weight: .bold, design: .serif))
                .monospacedDigit()
                .foregroundColor(.textPrimary.opacity(0.55))
                .contentTransition(.numericText())
                // A held notification pushes the rest of the lock screen back.
                .opacity(shown.isExpanded ? 0.25 : 1)
                .blur(radius: shown.isExpanded ? 3 : 0)

            VStack(spacing: 8) {
                if shown.isDelivered {
                    banner
                        .demoTouch(holdTouch, pressScale: 0.97)
                        .transition(
                            .offset(y: -36)
                                .combined(with: .scale(scale: 0.94, anchor: .top))
                                .combined(with: .opacity)
                        )
                }

                if shown.isExpanded {
                    menu
                        .transition(.scale(scale: 0.85, anchor: .top).combined(with: .opacity))
                }
            }
            // Room for the banner and its menu is kept while they are away,
            // so the clock does not jump when they arrive.
            .frame(height: 214, alignment: .top)

            HStack(spacing: 7) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11))
                Text("Lock screen")
                    .font(.system(size: 13))
            }
            .foregroundColor(.textSecondary)
            .opacity(shown.isExpanded ? 0 : 1)
        }
    }

    /// The banner as the system draws a dose reminder: the app's icon, the
    /// title and body `ReminderRequestFactory` really sends.
    private var banner: some View {
        HStack(alignment: .top, spacing: 11) {
            AppLogo(size: 20, tint: .onAccent)
                .frame(width: 36, height: 36)
                .background(Color.accentPrimary)
                .clipShape(.rect(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text("💊 Time to take your meds")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text("now")
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                }

                Text("Time to take: \(Self.medication)")
                    .font(.system(size: 14))
                    .foregroundColor(.textPrimary.opacity(0.8))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(width: 306, alignment: .leading)
        .background(Color.appSurface)
        .clipShape(.rect(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.textPrimary.opacity(0.1), lineWidth: 1)
        )
    }

    /// The action menu a held reminder opens: the dose category's actions, in
    /// its order, with Skip in the system's destructive red.
    private var menu: some View {
        VStack(spacing: 0) {
            menuRow("Take Now", color: .textPrimary, touch: takeTouch)
            menuDivider
            menuRow("Snooze 15m", color: .textPrimary)
            menuDivider
            menuRow("Skip", color: .red)
        }
        .frame(width: 306)
        .background(Color.appSurface)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.textPrimary.opacity(0.1), lineWidth: 1)
        )
    }

    private func menuRow(_ title: LocalizedStringResource, color: Color, touch: TouchPhase = .none) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(color)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(Color.textPrimary.opacity(touch == .press ? 0.08 : 0))
        .overlay { TouchIndicator(phase: touch) }
    }

    private var menuDivider: some View {
        Rectangle()
            .fill(Color.textPrimary.opacity(0.1))
            .frame(height: 1)
    }

    // MARK: - App

    /// Where Take Now lands: today's list, the dose logged, the pack counted
    /// down.
    private var today: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                OnboardingCaption(text: "Afternoon")
                Spacer(minLength: 0)
                Text(verbatim: shown.isLogged ? "1 / 1" : "0 / 1")
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .foregroundColor(shown.isLogged ? .accentPrimary : .textSecondary)
                    .contentTransition(.numericText())
            }

            HStack(spacing: 12) {
                Text(verbatim: "14:00")
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .monospacedDigit()
                    .fixedSize()
                    .foregroundColor(.textPrimary)

                Text(verbatim: Self.medication)
                    .font(.system(size: 15))
                    .foregroundColor(.textPrimary)

                Spacer(minLength: 0)

                ZStack {
                    Circle()
                        .stroke(Color.accentPrimary, lineWidth: 2)
                    Circle()
                        .fill(Color.accentPrimary)
                        .scaleEffect(shown.isLogged ? 1 : 0.01)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.onAccent)
                        .scaleEffect(shown.isLogged ? 1 : 0.3)
                        .opacity(shown.isLogged ? 1 : 0)
                }
                .frame(width: 26, height: 26)
            }

            Rectangle()
                .fill(Color.textPrimary.opacity(0.08))
                .frame(height: 1)

            HStack {
                Text("Left in pack")
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
                Spacer(minLength: 0)
                Text(verbatim: "\(shown.left)")
                    .font(.system(size: 14, weight: .semibold))
                    .monospacedDigit()
                    .foregroundColor(.textPrimary)
                    .contentTransition(.numericText(value: Double(shown.left)))
            }
        }
        .onboardingCard(18, radius: 26)
    }
}

#Preview {
    ReminderPreview()
        .padding(40)
        .background(Color.appBackground)
}
