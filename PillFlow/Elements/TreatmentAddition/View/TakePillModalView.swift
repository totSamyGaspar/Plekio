//
//  TakePillModalView.swift
//  PillFlow
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI

struct TakePillModalView: View {
    @Environment(\.dismiss) private var dismiss

    /// With Reduce Transparency on, the blur behind the modal becomes a solid
    /// fill rather than a thinner blur.
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    // Pills scheduled for the same time
    let pills: [PillDose]
    var onTake: () -> Void
    var onSkip: () -> Void
    var onSnooze: () -> Void

    let appSurface = Color.appSurface
    let appBackground = Color.appBackground

    /// The three action buttons stack an icon over a label; at larger text
    /// sizes a fixed 85pt would clip the label.
    @ScaledMetric(relativeTo: .caption) private var actionRowHeight: CGFloat = 85

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            Rectangle()
                .fill(reduceTransparency
                      ? AnyShapeStyle(Color.appBackground)
                      : AnyShapeStyle(.ultraThinMaterial))
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                // MARK: - Header
                ZStack(alignment: .topTrailing) {
                    LinearGradient(
                        colors: [Color.blue.opacity(0.8), Color.accentPrimary.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    // All pills here share one time; the first one's will do.
                    if let firstPill = pills.first {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                            Text("Scheduled for \(firstPill.time.formatted(date: .omitted, time: .shortened))")
                        }
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                        .padding()
                    }

                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 50, height: 50)
                            Image(systemName: "bell.badge.fill")
                                .font(.title3)
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("MEDICATION ALERT")
                                .font(.caption.weight(.heavy))
                                .foregroundColor(.white.opacity(0.8))
                                .tracking(1.0)

                            // One string with the count, not a ternary: Russian and
                            // Ukrainian have three plural forms that two branches
                            // can't express. The "one" variant may drop the number.
                            Text("Time for your \(pills.count) pills")
                                .font(.title2.weight(.heavy))
                                .foregroundColor(.white)
                        }
                        Spacer()
                    }
                    .padding(24)
                    .padding(.top, 16)
                }

                // MARK: - Content Body
                VStack(spacing: 16) {

                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(pills) { pill in
                                HStack(spacing: 16) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.accentPrimary.opacity(0.1))
                                            .frame(width: 50, height: 50)
                                        Image(systemName: pill.formSystemImage)
                                            .font(.title2)
                                            .foregroundColor(.accentPrimary)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(pill.name)
                                            .font(.headline.weight(.bold))
                                            .foregroundColor(.textPrimary)
                                        // Separate Text values: each piece is its
                                        // own translatable string, not a
                                        // concatenation with rawValue.
                                        (Text("\(pill.dosage) pcs") + Text(verbatim: " • ") + Text(pill.period.title))
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(.accentPrimary)
                                    }
                                    Spacer()
                                }
                                .padding(16)
                                .background(appSurface)
                                .cornerRadius(16)
                            }
                        }
                    }
                    .frame(maxHeight: 220)

                    Spacer(minLength: 10)

                    // MARK: - Action Buttons
                    // Dismissal belongs to whoever presented the modal (MainTabView
                    // calls router.dismissSheet from these same callbacks); dismiss()
                    // used to be duplicated here.
                    HStack(spacing: 12) {
                        ActionButton(icon: "xmark", title: pills.count > 1 ? "Skip All" : "Skip", color: .textPrimary, bgColor: appSurface, action: onSkip)

                        ActionButton(icon: "clock", title: "Snooze 15m", color: .warningAmber, bgColor: Color.warningAmber.opacity(0.15), action: onSnooze)

                        Button(action: onTake) {
                            VStack(spacing: 8) {
                                Image(systemName: "checkmark")
                                    .font(.title3.weight(.bold))
                                Text(pills.count > 1 ? "Take All" : "Take Now")
                                    .font(.caption.weight(.bold))
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.9)
                            }
                            .foregroundColor(Color.onAccent)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.accentPrimary)
                            .cornerRadius(16)
                        }
                    }
                    .frame(height: actionRowHeight)
                }
                .padding(24)
                .background(appBackground)
            }
            .frame(maxWidth: 340)
            .fixedSize(horizontal: false, vertical: true)
            .cornerRadius(24)
            .shadow(color: .appShadow, radius: 40, x: 0, y: 20)
        }
    }
}

struct ActionButton: View {
    let icon: String
    /// LocalizedStringKey, not String: with String the compiler does not extract
    /// the call-site literal into the catalog, and the buttons stayed English.
    let title: LocalizedStringKey
    let color: Color
    let bgColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3.weight(.bold))
                    .foregroundColor(color)
                // The three buttons split the modal's width evenly, about 95pt each.
                // "Snooze 15m" in German ("15 Min. später") does not fit, so the label
                // scales down instead of being truncated.
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundColor(color.opacity(0.8))
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(bgColor)
            .cornerRadius(16)
        }
    }
}

#Preview {
    TakePillModalView(
        pills: [
            PillDose(medicationId: UUID(), name: "Sertraline", dosage: 1, formSystemImage: "pills.fill", time: Date(), period: .morning, isTaken: false, stockCount: 10, lowStockThreshold: 5),
            PillDose(medicationId: UUID(), name: "Vitamin D", dosage: 1, formSystemImage: "capsule.fill", time: Date(), period: .morning, isTaken: false, stockCount: 10, lowStockThreshold: 5)
        ],
        onTake: {}, onSkip: {}, onSnooze: {}
    )
    .appTheme()
}
