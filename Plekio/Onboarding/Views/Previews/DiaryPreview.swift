//
//  DiaryPreview.swift
//  Plekio
//

import SwiftUI

/// Slide 4: the diary — mood with its week, a pressure reading with its trend,
/// and the progress photos.
///
/// Three small cards rather than one big one: the slide's claim is that the
/// app records more than pills, and three separate things say that better than
/// one thing with three rows.
struct DiaryPreview: View {

    /// Heights of the week's mood bars, last one today.
    private let week: [CGFloat] = [0.40, 0.58, 0.46, 0.74, 0.66, 0.88, 1.0]

    var body: some View {
        VStack(spacing: 12) {
            mood
            pressure
            photos
        }
        .frame(width: 306)
    }

    private var mood: some View {
        VStack(alignment: .leading, spacing: 13) {
            OnboardingCaption(text: "Well-being")

            HStack(alignment: .bottom, spacing: 14) {
                Text("Good")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundColor(.textPrimary)

                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(week.enumerated()), id: \.offset) { index, height in
                        Capsule()
                            .fill(index == week.count - 1 ? Color.accentPrimary : Color.textPrimary.opacity(0.12))
                            .frame(width: 12, height: 34 * height)
                    }
                }
                .frame(height: 34)
            }

            HStack(spacing: 7) {
                Text(verbatim: "7,5")
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
                    .onboardingChip()
                Text(verbatim: "4/5")
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
                    .onboardingChip()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onboardingCard(18)
    }

    private var pressure: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                OnboardingCaption(text: "Blood Pressure")
                HStack(spacing: 0) {
                    Text(verbatim: "137").foregroundColor(.textPrimary)
                    Text(verbatim: "/").foregroundColor(.textSecondary)
                    Text(verbatim: "91").foregroundColor(.textPrimary)
                }
                .font(.system(size: 28, weight: .bold, design: .serif))
                Text(verbatim: "58")
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
            }

            Spacer(minLength: 0)

            trend
        }
        .onboardingCard(18)
    }

    /// Two lines, systolic above diastolic, with no axis: at this size it is a
    /// shape, not a chart, and gridlines would only be noise.
    private var trend: some View {
        ZStack {
            line([0.30, 0.42, 0.36, 0.58, 0.50, 0.74, 0.66, 0.86])
                .stroke(Color.warningAccent, style: .init(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            line([0.10, 0.16, 0.12, 0.22, 0.18, 0.30, 0.26, 0.36])
                .stroke(Color.textSecondary, style: .init(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
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

            Text("Before / after")
                .font(.system(size: 13))
                .foregroundColor(.textSecondary)
        }
        .onboardingCard(13)
    }
}

#Preview {
    DiaryPreview()
        .padding(40)
        .background(Color.appBackground)
}
