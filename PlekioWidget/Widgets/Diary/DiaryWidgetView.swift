//
//  DiaryWidgetView.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 22.10.2026.
//

import SwiftUI
import WidgetKit
import AppIntents

/// Before today's check-in, four moods to log in one tap; after it, the day's
/// mood and, on the medium one, sleep, water and energy. A tap elsewhere opens
/// the check-in form, as the daily diary reminder does.
struct DiaryWidgetView: View {
    let entry: DoseEntry

    @Environment(\.widgetFamily) private var family
    private var isMedium: Bool { family == .systemMedium }

    var body: some View {
        Group {
            if let snapshot = entry.snapshot, snapshot.covers(entry.date, calendar: entry.calendar) {
                if let day = snapshot.diaryEntry(onDayOf: entry.date, calendar: entry.calendar) {
                    logged(day)
                } else {
                    pending
                }
            } else {
                NeedsAppView()
            }
        }
        .containerBackground(Color.widgetSurface, for: .widget)
        .widgetURL(WidgetLink.diaryCheckIn.url)
    }

    private var header: some View {
        HStack(spacing: 5) {
            WidgetLogo(size: 14)
            Text("Diary")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.textSecondary)
                .lineLimit(1)
        }
    }

    // MARK: Pending

    private var pending: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Text("How are you feeling?")
                .font(.widgetSerif(isMedium ? 17 : 15, weight: .bold))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            if isMedium {
                HStack(spacing: 8) { moodButtons }
            } else {
                let moods = QuickMood.standard
                Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                    GridRow {
                        moodButton(moods[0])
                        moodButton(moods[1])
                    }
                    GridRow {
                        moodButton(moods[2])
                        moodButton(moods[3])
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var moodButtons: some View {
        ForEach(QuickMood.standard) { moodButton($0) }
    }

    /// Off until tapped; WidgetKit shows it picked at once while the app logs it.
    private func moodButton(_ quick: QuickMood) -> some View {
        Toggle(isOn: false, intent: LogMoodIntent(quick.mood)) { EmptyView() }
            .toggleStyle(MoodToggleStyle(emoji: quick.emoji, label: quick.label, showsLabel: isMedium))
    }

    // MARK: Logged

    @ViewBuilder
    private func logged(_ day: WidgetSnapshot.DiaryDay) -> some View {
        if isMedium {
            VStack(spacing: 4) {
                header
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 16) {
                    moodSummary(day, alignment: .center)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    details(day)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
            }
        } else {
            VStack(spacing: 0) {
                header
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 4)
                VStack(spacing: 6) {
                    moodSummary(day, alignment: .center)
                    Text(day.isQuickLog ? "Quick log" : "Energy: \(day.energyLevel)/5")
                        .font(.caption2)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                Spacer(minLength: 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func moodSummary(_ day: WidgetSnapshot.DiaryDay, alignment: HorizontalAlignment = .leading) -> some View {
        VStack(alignment: alignment, spacing: 6) {
            ZStack {
                Circle().fill(Color.accentPrimary.opacity(0.15))
                Text(verbatim: day.mood.emoji).font(.system(size: isMedium ? 26 : 22))
            }
            .frame(width: isMedium ? 48 : 40, height: isMedium ? 48 : 40)
            .accessibilityHidden(true)

            Text(day.mood.title)
                .font(.widgetSerif(isMedium ? 20 : 18))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("at \(day.checkInDate.formatted(date: .omitted, time: .shortened))")
                .font(.caption2)
                .foregroundStyle(Color.textTertiary)
        }
    }

    /// Sleep, water and energy; a quick log has only defaults there, so it asks for more.
    @ViewBuilder
    private func details(_ day: WidgetSnapshot.DiaryDay) -> some View {
        if day.isQuickLog {
            VStack(alignment: .leading, spacing: 4) {
                Text("Quick log")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.textPrimary)
                Text("Tap to add details")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                // "%@ hrs", as the diary's stats write sleep.
                detail(icon: "bed.double.fill", title: "Sleep",
                       value: Text("\(day.sleepHours.formatted(.number.precision(.fractionLength(0...1)))) hrs"))
                detail(icon: "drop.fill", title: "Water", value: Text("\(day.waterGlasses) glasses"))
                detail(icon: "bolt.fill", title: nil, value: Text("Energy: \(day.energyLevel)/5"))
            }
        }
    }

    private func detail(icon: String, title: LocalizedStringKey?, value: Text) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Color.accentPrimary)
                .frame(width: 16)
                .widgetAccentable()
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                if let title {
                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(Color.textSecondary)
                }
                value
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
