//
//  MedicationCardView.swift
//  Plekio
//
//  Created by Edward Gasparian on 20.05.2026.
//

import SwiftUI
import Combine

struct MedicationCardView: View {

    // MARK: - Properties

    let pill: PillDose
    let onAction: (DoseCardAction) -> Void

    let appSurface = Color.appSurface

    // MARK: - Derived state

    /// Taken or skipped: the row recedes. Only taken gets the strikethrough.
    private var isSettled: Bool { pill.status.isSettled }

    /// Overlay colour, label and tint for missed/skipped cards; nil otherwise.
    private var state: (wash: Color, label: LocalizedStringKey, tint: Color)? {
        if pill.isMissed { return (.missedWash, "MISSED", .warningAccent) }
        if pill.isSkipped { return (.skippedWash, "SKIPPED", .textSecondary) }
        return nil
    }

    private var isLowStock: Bool {
        guard let stock = pill.stockCount else { return false }
        return StockRules.isLow(stock: stock, threshold: pill.lowStockThreshold)
    }

    /// Dosage and remaining stock as one run of text.
    private var dosageAndStock: Text {
        let dosage = Text("\(pill.dosage) pcs")
            .foregroundStyle(Color.textPrimary.opacity(0.7))

        guard let stock = pill.stockCount else { return dosage }

        return dosage
        + Text(verbatim: "  ·  ").foregroundStyle(Color.textPrimary.opacity(0.3))
        + Text("Stock: \(stock)")
            .foregroundStyle(isLowStock ? Color.warningAmber : Color.textPrimary.opacity(0.7))
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 16) {
            MedicationPhotoView(medicationId: pill.medicationId, size: 48, cornerRadius: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(Color.iconTile)
                    Image(systemName: pill.form.systemImage)
                        .font(.title2)
                        .foregroundColor(.accentPrimary)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.textPrimary.opacity(0.1), lineWidth: 1))
            .opacity(isSettled ? 0.6 : 1.0)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(pill.name)
                        .font(.headline.weight(.bold))
                        .foregroundColor(isSettled ? .textSecondary : .textPrimary)
                        .strikethrough(pill.isTaken)
                        .lineLimit(2)

                    Text(pill.time.formatted(date: .omitted, time: .shortened))
                        .font(.caption2.weight(.heavy))
                        .foregroundColor(.accentPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentPrimary.opacity(0.15))
                        .cornerRadius(8)
                }

                HStack(spacing: 6) {
                    dosageAndStock
                        .font(.caption)
                        .animatedNumber(Double(pill.stockCount ?? 0))

                    if isLowStock {
                        Text("LOW")
                            .scaledFont(size: 11, relativeTo: .caption2, weight: .heavy)
                            .foregroundColor(.warningAmber)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.warningAmber.opacity(0.2))
                            .cornerRadius(4)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.warningAmber, lineWidth: 1))
                            .layoutPriority(1)
                    }
                }
            }

            Spacer()

            statusIndicator
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(appSurface)
        }
        .overlay { stateCloth }
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture {
            if pill.isLoggable && !isSettled && !pill.isMissed { onAction(.open) }
        }
        .contextMenu { contextMenuItems }
    }

    // MARK: - Subviews

    /// Translucent state overlay; kept out of layout so long labels can't wrap the text column.
    @ViewBuilder
    private var stateCloth: some View {
        if let state {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(state.wash)
                .overlay(alignment: .topTrailing) {
                    Text(state.label)
                        .font(.caption2.weight(.heavy))
                        .foregroundColor(state.tint)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                // Must not swallow taps meant for the checkmark underneath.
                .allowsHitTesting(false)
        }
    }

    /// One button for every state, so the symbol can morph between them.
    /// Skipped and missed doses stay loggable; a logged one can be undone.
    private var statusIndicator: some View {
        Button { onAction(.toggle) } label: {
            Image(systemName: pill.isTaken ? "checkmark.circle.fill" : "checkmark.circle")
                .font(.title)
                .foregroundColor(checkmarkTint)
                .animatedSymbol(pill.isTaken)
        }
        .buttonStyle(.plain)
        .expandTouchTarget(8)
        .disabled(!pill.isLoggable)
        .accessibilityLabel(checkmarkLabel)
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        ForEach(DoseCardAction.menu(for: pill), id: \.self) { action in
            Button { onAction(action) } label: {
                Label(action.title(for: pill), systemImage: action.systemImage(for: pill))
            }
        }
    }

        private var checkmarkTint: Color {
        if pill.isTaken { return .accentPrimary }
        if !pill.isLoggable { return .textPrimary.opacity(0.1) }
        return pill.isMissed ? .warningAccent : .textTertiary
    }

    private var checkmarkLabel: Text {
        if pill.isTaken { return Text("Undo logging \(pill.name)") }
        if pill.isMissed { return Text("Log the missed dose of \(pill.name)") }
        return Text("Log \(pill.name)")
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        VStack(spacing: 20) {
            MedicationCardView(
                pill: PillDose(
                    medicationId: UUID(),
                    name: "Sertraline",
                    dosage: 1,
                    form: .pill,
                    time: Date(),
                    period: .morning,
                    stockCount: 9,
                    lowStockThreshold: 10
                ),
                onAction: { print("Action: \($0)") }
            )

            MedicationCardView(
                pill: PillDose(
                    medicationId: UUID(),
                    name: "Vitamin D",
                    dosage: 1,
                    form: .capsule,
                    time: Date().addingTimeInterval(3600),
                    period: .morning,
                    status: .taken(at: Date(), dispensed: 1),
                    stockCount: 25,
                    lowStockThreshold: 10
                ),
                onAction: { print("Action: \($0)") }
            )

            MedicationCardView(
                pill: PillDose(
                    medicationId: UUID(),
                    name: "Folic Acid",
                    dosage: 1,
                    form: .pill,
                    time: Date().addingTimeInterval(-3600),
                    period: .morning,
                    status: .skipped(at: Date()),
                    stockCount: 25,
                    lowStockThreshold: 10
                ),
                onAction: { print("Action: \($0)") }
            )

            MedicationCardView(
                pill: PillDose(
                    medicationId: UUID(),
                    name: "Magnesium",
                    dosage: 2,
                    form: .capsule,
                    time: Date().addingTimeInterval(-7200),
                    period: .morning,
                    stockCount: 25,
                    lowStockThreshold: 10
                ),
                onAction: { print("Action: \($0)") }
            )
        }
        .padding()
    }
    .appTheme()
}
