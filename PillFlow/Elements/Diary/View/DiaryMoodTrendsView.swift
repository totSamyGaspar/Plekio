//
//  DiaryMoodTrendsView.swift
//  PillFlow
//
//  Created by Edward Gasparian on 24.08.2026.
//
//  The "Mood & Trends" tab: the mood chart and the sleep/energy card.
//  Split out of DiaryView.
//

import SwiftUI

struct DiaryMoodTrendsView: View {
    let entries: [DiaryEntry]
    let avgEnergyLevel: Double
    let avgSleepHours: Double

    /// Most recent entries, oldest first, so the chart reads left-to-right
    /// chronologically.
    private var moodChartEntries: [DiaryEntry] {
        Array(entries.prefix(7)).sorted { $0.checkInDate < $1.checkInDate }
    }

    var body: some View {
        VStack(spacing: 16) {
            moodProgressionCard
            physicalEnergyCard
        }
        .padding(.horizontal)
    }

    private var moodProgressionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Mood & Well-being Progression")
                    .scaledFont(size: 18, relativeTo: .headline, weight: .bold, design: .serif)
                    .foregroundColor(.textPrimary)
                Text("Daily reported emotional and physical state")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }

            if moodChartEntries.isEmpty {
                Text("Log a few check-ins to see your mood trend here.")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else {
                HStack(alignment: .bottom, spacing: 14) {
                    ForEach(moodChartEntries) { entry in
                        moodBar(entry)
                    }
                }
            }

            // A second chip, "Adherence Positively Correlated", used to sit here.
            // No correlation was ever computed — it appeared whenever average mood
            // was >= 3.5, presenting an invention as a finding. moodBaselineLabel
            // stays: it really is derived from the entries.
            Text(moodBaselineLabel)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.appBackground)
                .clipShape(Capsule())
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(Color.appSurface)
        .cornerRadius(20)
    }

    /// Fixed bar width (matches WeeklyAdherenceView's per-bar sizing) — kept
    /// constant regardless of entry count so a chart with only 1-2 entries
    /// doesn't stretch its bars into wide, flattened domes.
    private let moodBarWidth: CGFloat = 40

    private func moodBar(_ entry: DiaryEntry) -> some View {
        let mood = DiaryMood(rawValue: entry.moodLabel)
        let heightFraction = CGFloat(entry.moodScore) / 5.0

        return VStack(spacing: 8) {
            ZStack(alignment: .bottom) {
                TopRoundedBar()
                    .fill(Color.textPrimary.opacity(0.06))
                TopRoundedBar()
                    .fill(Color.accentPrimary)
                    .frame(height: max(16, 80 * heightFraction))
                    .shadow(color: Color.accentPrimary.opacity(0.3), radius: 5, x: 0, y: -5)
                    .overlay(alignment: .top) {
                        Text(mood?.emoji ?? "🙂")
                            .font(.caption2)
                            .padding(4)
                            .background(Circle().fill(Color.appSurface))
                            .offset(y: -10)
                    }
            }
            .frame(width: moodBarWidth, height: 80)

            Text(entry.checkInDate.formatted(.dateTime.weekday(.abbreviated)))
                .font(.caption2.weight(.bold))
                .foregroundColor(.textSecondary)
        }
        .frame(width: moodBarWidth)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.checkInDate.formatted(.dateTime.weekday(.wide)))
        .accessibilityValue(Text(mood?.title ?? DiaryMood.neutral.title))
    }

    private var moodBaselineLabel: LocalizedStringKey {
        guard moodChartEntries.count >= 2 else { return "Baseline: Not Enough Data" }
        let half = moodChartEntries.count / 2
        let firstHalf = moodChartEntries.prefix(half)
        let secondHalf = moodChartEntries.suffix(half)
        let firstAvg = Double(firstHalf.reduce(0) { $0 + $1.moodScore }) / Double(firstHalf.count)
        let secondAvg = Double(secondHalf.reduce(0) { $0 + $1.moodScore }) / Double(secondHalf.count)
        let delta = secondAvg - firstAvg
        if delta > 0.4 { return "Baseline: Improving" }
        if delta < -0.4 { return "Baseline: Declining" }
        return "Baseline: Stable Mood"
    }

    private var physicalEnergyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Physical Energy & Rest")
                    .scaledFont(size: 18, relativeTo: .headline, weight: .bold, design: .serif)
                    .foregroundColor(.textPrimary)
                Text("Impact of sleep hours on daytime vitality")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }

            metricBar(
                icon: "moon.fill", iconColor: .purple,
                title: "Average Sleep Quality",
                valueText: "\(avgSleepHours, format: .number.precision(.fractionLength(1))) hrs / night",
                progress: min(avgSleepHours / 9.0, 1.0),
                tint: .purple
            )

            metricBar(
                icon: "bolt.fill", iconColor: .warmAccent,
                title: "Daytime Energy Baseline",
                valueText: "\(avgEnergyLevel, format: .number.precision(.fractionLength(1))) / 5",
                progress: min(avgEnergyLevel / 5.0, 1.0),
                tint: .warmAccent
            )
        }
        .padding(18)
        .background(Color.appSurface)
        .cornerRadius(20)
    }

    private func metricBar(icon: String, iconColor: Color, title: LocalizedStringKey, valueText: LocalizedStringKey, progress: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: icon).foregroundColor(iconColor)
                    Text(title).foregroundColor(.textPrimary.opacity(0.8))
                }
                .font(.subheadline.weight(.semibold))
                Spacer()
                Text(valueText)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(tint)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6).fill(Color.textPrimary.opacity(0.08))
                    RoundedRectangle(cornerRadius: 6).fill(tint).frame(width: max(4, geo.size.width * progress))
                }
            }
            .frame(height: 8)
        }
    }
}
