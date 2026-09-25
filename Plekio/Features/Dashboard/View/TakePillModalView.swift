//
//  TakePillModalView.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI

struct TakePillModalView: View {

    // MARK: - Properties

    @Environment(\.dismiss) private var dismiss

    /// Swaps the backdrop blur for a solid fill.
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let pills: [PillDose]
    var onTake: () -> Void
    var onSkip: () -> Void
    var onSnooze: () -> Void

    let appSurface = Color.appSurface
    let appBackground = Color.appBackground

    /// Scaled so icon-over-label buttons don't clip at large text sizes.
    @ScaledMetric(relativeTo: .caption) private var actionRowHeight: CGFloat = 85

    /// Scaled so cards aren't cut mid-word at large text sizes.
    @ScaledMetric(relativeTo: .headline) private var listMaxHeight: CGFloat = 220

    @State private var listContentHeight: CGFloat = 0
    @State private var listViewportHeight: CGFloat = 0

    // MARK: - Derived state

    private var listOverflows: Bool { listContentHeight > listViewportHeight + 1 }

    /// A single time, or a range when the doses span several times.
    private var scheduleText: String {
        let times = pills.map(\.time)
        guard let earliest = times.min() else { return "" }
        let earliestText = earliest.formatted(date: .omitted, time: .shortened)

        guard let latest = times.max(), latest != earliest else { return earliestText }
        return "\(earliestText) – \(latest.formatted(date: .omitted, time: .shortened))"
    }

    /// Fades the edges only when the list actually overflows.
    @ViewBuilder
    private var listEdgeFade: some View {
        if listOverflows {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.05),
                    .init(color: .black, location: 0.95),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            Rectangle()
        }
    }

    // MARK: - Body

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
                ZStack(alignment: .topTrailing) {
                    LinearGradient(
                        colors: [Color.blue.opacity(0.8), Color.accentPrimary.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    if !scheduleText.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                            Text("Scheduled for \(scheduleText)")
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
                            Text("Time for your meds")
                                .font(.title3.weight(.heavy))
                                .foregroundColor(.white)
                        }
                        Spacer()
                    }
                    .padding(24)
                    .padding(.top, 36)
                }

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
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                            listContentHeight = $0
                        }
                    }
                    .frame(maxHeight: listMaxHeight)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                        listViewportHeight = $0
                    }
                    .scrollIndicators(listOverflows ? .visible : .automatic)
                    .mask { listEdgeFade }

                    Spacer(minLength: 10)

                    HStack(spacing: 12) {
                        ActionButton(icon: "xmark", title: pills.count > 1 ? "Skip All" : "Skip", color: .textPrimary, bgColor: appSurface, action: onSkip)

                        ActionButton(icon: "clock", title: "Snooze 15m", color: .warningAmber, bgColor: Color.warningAmber.opacity(0.15), action: onSnooze)

                        ActionButton(
                            icon: "checkmark",
                            title: pills.count > 1 ? "Take All" : "Take Now",
                            color: Color.onAccent,
                            bgColor: Color.accentPrimary,
                            titleOpacity: 1,
                            action: onTake
                        )
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

// MARK: - ActionButton

struct ActionButton: View {
    let icon: String
    /// LocalizedStringKey, not String, so call-site literals get localized.
    let title: LocalizedStringKey
    let color: Color
    let bgColor: Color
    /// Muted tiles dim their label; the filled accent tile needs 1.
    var titleOpacity: Double = 0.8
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3.weight(.bold))
                    .foregroundColor(color)

                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundColor(color.opacity(titleOpacity))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.9)
                    .padding(.horizontal, 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(bgColor)
            .cornerRadius(16)
        }
    }
}

// MARK: - Preview

#Preview {
    TakePillModalView(
        pills: [
            PillDose(medicationId: UUID(), name: "Sertraline", dosage: 1, formSystemImage: "pills.fill", time: Date(), period: .morning, stockCount: 10, lowStockThreshold: 5),
            PillDose(medicationId: UUID(), name: "Vitamin D", dosage: 1, formSystemImage: "capsule.fill", time: Date(), period: .morning, stockCount: 10, lowStockThreshold: 5)
        ],
        onTake: {}, onSkip: {}, onSnooze: {}
    )
    .appTheme()
}
