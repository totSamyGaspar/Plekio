//
//  DiaryEntryRowView.swift
//  PillFlow
//
//  Created by Edward Gasparian on 24.08.2026.
//

import SwiftUI

struct DiaryEntryRowView: View {
    let entry: DiaryEntry
    var onEdit: () -> Void
    var onDelete: () -> Void

    private var mood: DiaryMood? { DiaryMood(rawValue: entry.moodLabel) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                HStack(spacing: 8) {
                    Text(mood?.emoji ?? "📝")
                    // .textCase, not .uppercased(): case is a display concern, and
                    // per-character uppercasing misbehaves in some languages.
                    Text("\(entry.moodTitle) (\(entry.moodScore)/5)")
                        .font(.caption.weight(.heavy))
                        .textCase(.uppercase)
                }
                .foregroundColor(.accentPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.accentPrimary.opacity(0.12))
                .cornerRadius(10)

                Spacer()

                Text("at \(entry.checkInDate.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }

            Text(entry.checkInDate.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                .scaledFont(size: 19, relativeTo: .headline, weight: .bold, design: .serif)
                .foregroundColor(.textPrimary)

            // A quick-logged entry (home screen's one-tap mood chips) never
            // showed the energy/sleep/water fields to the user at all — their
            // values on the model are just DiaryEntryDraft's static defaults,
            // not anything reported. Showing these chips for such an entry
            // would present fabricated numbers as real data.
            if entry.isQuickLog {
                Text("Quick mood log — no detailed metrics recorded")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.textSecondary)
            } else {
                HStack(spacing: 10) {
                    statChip(icon: "bolt.fill", iconColor: .yellow, text: "Energy: \(entry.energyLevel)/5")
                    let sleepQuality = SleepQuality(rawValue: entry.sleepQuality) ?? .good
                    statChip(
                        icon: "moon.fill",
                        iconColor: .purple,
                        text: "\(entry.sleepHours, format: .number.precision(.fractionLength(0)))h · \(String(localized: sleepQuality.title))"
                    )
                    statChip(icon: "drop.fill", iconColor: .blue, text: "\(entry.waterGlasses) glasses")
                    if entry.discomfortLevel > 0 {
                        statChip(icon: "heart.fill", iconColor: .pink, text: "Pain: \(entry.discomfortLevel)/10")
                    }
                }
            }

            if !entry.physicalSummary.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PHYSICAL STATE & SENSATIONS")
                        .font(.caption2.weight(.heavy))
                        .foregroundColor(.textSecondary)
                    Text(entry.physicalSummary)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.textPrimary.opacity(0.9))
                }
            }

            if !entry.reflectionNotes.isEmpty {
                Text(entry.reflectionNotes)
                    .font(.subheadline)
                    .foregroundColor(.textPrimary.opacity(0.7))
                    .lineLimit(4)
            }

            if !entry.symptoms.isEmpty || !entry.milestoneTags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(entry.symptoms, id: \.self) { symptom in
                        smallTag(text: DiarySymptomOptions.title(for: symptom), color: .accentPrimary)
                    }
                    ForEach(entry.milestoneTags, id: \.self) { tag in
                        smallTag(text: "#\(DiaryMilestoneOptions.title(for: tag))", color: .milestonePurple)
                    }
                }
            }

            if !entry.photoIds.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("PROGRESS PHOTOS (\(entry.photoIds.count))")
                            .font(.caption2.weight(.heavy))
                            .foregroundColor(.textSecondary)
                        Spacer()
                        Text("Tap photo to zoom")
                            .font(.caption2)
                            .foregroundColor(.textSecondary)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 8) {
                            ForEach(entry.photoIds, id: \.self) { photoId in
                                DiaryAsyncPhoto(photoId: photoId)
                                    .frame(width: 68, height: 68)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }
            }

            HStack(spacing: 16) {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.textSecondary)
                }
                .expandTouchTarget(vertical: 14, horizontal: 6)
                Button(action: onDelete) {
                    Label("Delete", systemImage: "trash")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.warningAccent)
                }
                .expandTouchTarget(vertical: 14, horizontal: 6)
                Spacer()
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(Color.appSurface)
        .cornerRadius(24)
    }

    private func statChip(icon: String, iconColor: Color, text: LocalizedStringKey) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).foregroundColor(iconColor)
            Text(text).foregroundColor(.textPrimary.opacity(0.8))
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.appBackground)
        .cornerRadius(8)
    }

    private func smallTag(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

#Preview {
    DiaryEntryRowView(
        entry: DiaryEntry(
            checkInDate: Date(),
            moodLabel: DiaryMood.great.rawValue,
            moodScore: 5,
            physicalSummary: "Woke up clear-headed with stable energy. No morning nausea after breakfast.",
            energyLevel: 4,
            discomfortLevel: 0,
            sleepHours: 8,
            sleepQuality: SleepQuality.good.rawValue,
            waterGlasses: 6,
            symptoms: ["Mild Nausea"],
            reflectionNotes: "Today marks day 14 on my adjusted morning Sertraline routine. Sticking strictly to taking it with oatmeal and a full cup of water has completely resolved the previous stomach sensitivity.",
            milestoneTags: ["Day 14 Milestone"]
        ),
        onEdit: {}, onDelete: {}
    )
    .padding()
    .background(Color.appBackground)
    .appTheme()
}
