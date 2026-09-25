//
//  DiaryPreview.swift
//  Plekio
//

import SwiftUI

/// Slide 4: the diary — mood with its week, a pressure reading with its trend,
/// and the progress photos.
///
/// The week rises bar by bar and waits on an empty slot for today; a tap fills
/// it and names the day. The pressure reading counts up as its trend draws
/// itself, and two taps put a before and an after into the photos.
///
/// Three small cards rather than one big one: the slide's claim is that the
/// app records more than pills, and three separate things say that better than
/// one thing with three rows.
struct DiaryPreview: View {

    var isActive = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var now = Frame.opening
    @State private var moodTouch = TouchPhase.none
    @State private var photoTouch = TouchPhase.none

    /// Heights of the six days before today.
    private let week: [CGFloat] = [0.40, 0.58, 0.46, 0.74, 0.66, 0.88]

    private struct Frame {
        var isWeekShown = false
        var isMoodSet = false
        var systolic = 0
        var diastolic = 0
        var pulse = 0
        var trend: CGFloat = 0
        var photos = 0
        var isAddShown = true

        static let opening = Frame()
        static let finished = Frame(
            isWeekShown: true,
            isMoodSet: true,
            systolic: 137,
            diastolic: 91,
            pulse: 58,
            trend: 1,
            photos: 2,
            isAddShown: false
        )
    }

    private var shown: Frame { reduceMotion ? .finished : now }

    var body: some View {
        VStack(spacing: 12) {
            mood
            pressure
            photos
        }
        .frame(width: 306)
        .task(id: isActive) {
            guard isActive, !reduceMotion else { return }
            await Demo.loop(scene) {
                now = .opening
                moodTouch = .none
                photoTouch = .none
            }
        }
    }

    // MARK: - Scene

    private func scene() async throws {
        try await Demo.wait(0.4)
        now.isWeekShown = true      // each bar carries its own staggered spring

        try await Demo.wait(0.9)
        try await Demo.tap($moodTouch) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) { now.isMoodSet = true }
        }

        try await Demo.wait(0.4)
        withAnimation(.easeInOut(duration: 1.0)) { now.trend = 1 }
        let steps = 14
        for step in 1...steps {
            withAnimation(.snappy(duration: 0.12)) {
                now.systolic = 137 * step / steps
                now.diastolic = 91 * step / steps
                now.pulse = 58 * step / steps
            }
            try await Demo.wait(0.05)
        }

        try await Demo.wait(0.7)
        try await Demo.tap($photoTouch) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { now.photos = 1 }
        }
        try await Demo.wait(0.15)
        try await Demo.tap($photoTouch) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { now.photos = 2 }
        }
        withAnimation(.easeOut(duration: 0.25)) { now.isAddShown = false }

        try await Demo.wait(2.6)
        withAnimation(.easeInOut(duration: 0.5)) { now = .opening }
        try await Demo.wait(0.8)
    }

    // MARK: - UI Components

    private var mood: some View {
        VStack(alignment: .leading, spacing: 13) {
            OnboardingCaption(text: "Well-being")

            HStack(alignment: .bottom, spacing: 14) {
                ZStack(alignment: .leading) {
                    if shown.isMoodSet {
                        Text("Good").transition(.blurReplace)
                    } else {
                        Text(verbatim: "—").transition(.blurReplace)
                    }
                }
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundColor(.textPrimary)

                Spacer(minLength: 0)

                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(week.enumerated()), id: \.offset) { index, height in
                        Capsule()
                            .fill(Color.textPrimary.opacity(0.12))
                            .frame(width: 12, height: 34 * (shown.isWeekShown ? height : 0.12))
                            .animation(
                                .spring(response: 0.45, dampingFraction: 0.7).delay(Double(index) * 0.06),
                                value: shown.isWeekShown
                            )
                    }
                    today
                }
                .frame(height: 34)
            }

            HStack(spacing: 7) {
                ForEach(Array(["7,5", "4/5"].enumerated()), id: \.offset) { index, value in
                    Text(verbatim: value)
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                        .onboardingChip()
                        .opacity(shown.isMoodSet ? 1 : 0)
                        .offset(y: shown.isMoodSet ? 0 : 4)
                        .animation(.snappy.delay(0.15 + Double(index) * 0.08), value: shown.isMoodSet)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onboardingCard(18)
    }

    /// Today's slot: an outline waiting for a tap, then the tallest bar.
    private var today: some View {
        ZStack(alignment: .bottom) {
            Capsule()
                .strokeBorder(
                    Color.textPrimary.opacity(0.25),
                    style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])
                )
                .opacity(shown.isMoodSet ? 0 : 1)

            Capsule()
                .fill(Color.accentPrimary)
                .frame(height: shown.isMoodSet ? 34 : 0)
        }
        .frame(width: 12, height: 34)
        .demoTouch(moodTouch, pressScale: 0.85)
    }

    private var pressure: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                OnboardingCaption(text: "Blood Pressure")
                HStack(spacing: 0) {
                    reading(shown.systolic).foregroundColor(.textPrimary)
                    Text(verbatim: "/").foregroundColor(.textSecondary)
                    reading(shown.diastolic).foregroundColor(.textPrimary)
                }
                .font(.system(size: 28, weight: .bold, design: .serif))
                reading(shown.pulse)
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
            }

            Spacer(minLength: 0)

            trend
        }
        .onboardingCard(18)
    }

    private func reading(_ value: Int) -> some View {
        Text(verbatim: value == 0 ? "—" : "\(value)")
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(value)))
    }

    /// Two lines, systolic above diastolic, with no axis: at this size it is a
    /// shape, not a chart, and gridlines would only be noise.
    private var trend: some View {
        let style = StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)

        return ZStack {
            line([0.30, 0.42, 0.36, 0.58, 0.50, 0.74, 0.66, 0.86])
                .trim(from: 0, to: shown.trend)
                .stroke(Color.warningAccent, style: style)
            line([0.10, 0.16, 0.12, 0.22, 0.18, 0.30, 0.26, 0.36])
                .trim(from: 0, to: shown.trend)
                .stroke(Color.textSecondary, style: style)
        }
        .frame(width: 128, height: 52)
    }

    private func line(_ values: [CGFloat]) -> Path {
        Path { path in
            let step = 128 / CGFloat(values.count - 1)
            for (index, value) in values.enumerated() {
                let point = CGPoint(x: CGFloat(index) * step, y: 52 - value * 52)
                index == 0 ? path.move(to: point) : path.addLine(to: point)
            }
        }
    }

    private var photos: some View {
        HStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 15))
                .foregroundColor(.milestonePurple)
                .frame(width: 34, height: 34)
                .background(Color.milestonePurple.opacity(0.16))
                .clipShape(.rect(cornerRadius: 11))

            Text("Progress photos")
                .font(.system(size: 14))
                .foregroundColor(.textPrimary)

            Spacer(minLength: 0)

            HStack(spacing: 5) {
                if shown.photos >= 1 {
                    thumbnail(isAfter: false)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
                if shown.photos >= 2 {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.textSecondary)
                        .transition(.opacity)
                    thumbnail(isAfter: true)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
                if shown.isAddShown {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.milestonePurple)
                        .frame(width: 28, height: 28)
                        .background(Color.milestonePurple.opacity(0.16))
                        .clipShape(.circle)
                        .demoTouch(photoTouch, pressScale: 0.85)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }
            .frame(height: 34)
        }
        .onboardingCard(13)
    }

    /// A stand-in photo: the before paler than the after, which is the
    /// comparison the pair exists for.
    private func thumbnail(isAfter: Bool) -> some View {
        RoundedRectangle(cornerRadius: 7)
            .fill(Color.milestonePurple.opacity(isAfter ? 0.55 : 0.22))
            .frame(width: 26, height: 26)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.85))
            )
    }
}

#Preview {
    DiaryPreview()
        .padding(40)
        .background(Color.appBackground)
}
