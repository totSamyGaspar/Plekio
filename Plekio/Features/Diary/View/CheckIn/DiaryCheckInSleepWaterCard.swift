//
//  DiaryCheckInSleepWaterCard.swift
//  Plekio
//
//  Created by Edward Gasparian on 03.09.2026.
//

import SwiftUI

/// Sleep duration and quality above, water glasses below, in one card.
struct DiarySleepWaterCard: View {

    // MARK: - Properties

    @Binding var sleepHours: Double
    @Binding var sleepQuality: SleepQuality
    @Binding var waterGlasses: Int

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            sleep
            Divider().opacity(0.15)
            water
        }
        .padding(18)
        .background(Color.appSurface)
        .cornerRadius(18)
    }

    // MARK: - Sleep

    private var sleep: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "moon.stars.fill").foregroundColor(.purple)
                Text("Sleep Duration & Quality")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.textPrimary)
            }
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    // Range is enforced by DiaryEntryDraft, not here.
                    TextField("7.5", value: $sleepHours, format: .number)
                        .keyboardType(.decimalPad)
                        .foregroundColor(.textPrimary)
                        .frame(width: 40)
                    Text("hours").foregroundColor(.textSecondary).font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.appBackground)
                .cornerRadius(10)

                Spacer()

                HStack(spacing: 6) {
                    ForEach(SleepQuality.allCases) { quality in
                        Button {
                            sleepQuality = quality
                        } label: {
                            Text(quality.initial)
                                .font(.caption.weight(.heavy))
                                .frame(width: 30, height: 30)
                                .background(sleepQuality == quality ? Color.accentPrimary : Color.appBackground)
                                .foregroundColor(sleepQuality == quality ? Color.onAccent : .textSecondary)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(sleepQuality == quality ? .isSelected : [])
                    }
                }
            }
        }
    }

    // MARK: - Water

    private var water: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "drop.fill").foregroundColor(.blue)
                Text("Water Hydration")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.textPrimary)
            }
            HStack {
                Button {
                    waterGlasses -= 1
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 32, height: 32)
                        .background(Color.appBackground)
                        .foregroundColor(.textPrimary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .expandTouchTarget(6)

                Spacer()
                VStack(spacing: 2) {
                    Text("\(waterGlasses) glasses")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.textPrimary)
                    Text("(~\(waterGlasses * 250)ml)")
                        .font(.caption2)
                        .foregroundColor(.textSecondary)
                }
                Spacer()

                Button {
                    waterGlasses += 1
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 32, height: 32)
                        .background(Color.accentPrimary)
                        .foregroundColor(Color.onAccent)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .expandTouchTarget(6)
            }
            // One adjustable VoiceOver element (swipe up/down), like a stepper.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Water Hydration")
            .accessibilityValue("\(waterGlasses) glasses")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    waterGlasses += 1
                case .decrement:
                    waterGlasses -= 1
                @unknown default:
                    break
                }
            }
        }
    }
}
