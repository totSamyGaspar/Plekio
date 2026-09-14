//
//  MedicationCardView.swift
//  PillFlow
//
//  Created by Edward Gasparian on 20.05.2026.
//

import SwiftUI
import Combine

struct MedicationCardView: View {
    let pill: PillDose
    let onToggle: () -> Void
    let onTapCard: () -> Void
    
    let appSurface = Color.appSurface
    
    /// Taken or skipped: either way the user has answered for this dose, and the
    /// row recedes. Only a taken one gets the strikethrough — a skip is a decision
    /// about the dose, not a record of having swallowed it.
    private var isSettled: Bool { pill.isTaken || pill.isSkipped }
    
    private var isLowStock: Bool {
        guard let stock = pill.stockCount else { return false }
        return stock <= pill.lowStockThreshold
    }
    
    /// Dosage and remaining stock as one run of text.
    ///
    private var dosageAndStock: Text {
        let dosage = Text("\(pill.dosage) pcs")
            .foregroundStyle(Color.textPrimary.opacity(0.7))
        
        guard let stock = pill.stockCount else { return dosage }
        
        return dosage
        + Text(verbatim: "  ·  ").foregroundStyle(Color.textPrimary.opacity(0.3))
        + Text("Stock: \(stock) remaining")
            .foregroundStyle(isLowStock ? Color.warningAmber : Color.textPrimary.opacity(0.7))
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // MARK: - Icon / Image
            
            MedicationPhotoView(medicationId: pill.medicationId, size: 48, cornerRadius: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(Color.iconTile)
                    Image(systemName: pill.formSystemImage)
                        .font(.title2)
                        .foregroundColor(.accentPrimary)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.textPrimary.opacity(0.1), lineWidth: 1))
            .opacity(isSettled ? 0.6 : 1.0)
            
            // MARK: - Info Text
            
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
            
            // MARK: - Status Indicators
            
            statusIndicator
        }
        .padding()
        .background(appSurface)
        .cornerRadius(20)
        .onTapGesture {
            if pill.isLoggable && !isSettled && !pill.isMissed { onTapCard() }
        }
    }
    
    // MARK: - Status Indicator
    
    @ViewBuilder
    private var statusIndicator: some View {
        if pill.isTaken {
            Button(action: onToggle) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.accentPrimary)
            }
            .buttonStyle(.plain)
            .expandTouchTarget(8)
            .disabled(!pill.isLoggable)
            .accessibilityLabel("Undo logging \(pill.name)")
        } else if pill.isSkipped {
            HStack(spacing: 8) {
                Text("SKIPPED")
                    .font(.caption2.weight(.heavy))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.textSecondary.opacity(0.12))
                    .foregroundColor(.textSecondary)
                    .cornerRadius(6)
                
                // Still offered, because a skip is a decision and not a locked
                // door: changing your mind logs the dose and clears the skip.
                Button(action: onToggle) {
                    Image(systemName: "checkmark.circle")
                        .font(.title)
                        .foregroundColor(.textTertiary)
                }
                .buttonStyle(.plain)
                .expandTouchTarget(8)
                .disabled(!pill.isLoggable)
                .accessibilityLabel("Log \(pill.name)")
            }
        } else if pill.isLoggable {
            HStack(spacing: 8) {
                if pill.isMissed {
                    Text("MISSED")
                        .font(.caption2.weight(.heavy))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.warningAccent.opacity(0.12))
                        .foregroundColor(.warningAccent)
                        .cornerRadius(6)
                }
                
                Button(action: onToggle) {
                    Image(systemName: "checkmark.circle")
                        .font(.title)
                        .foregroundColor(pill.isMissed ? .warningAccent : .textTertiary)
                }
                .buttonStyle(.plain)
                .expandTouchTarget(8)
                .accessibilityLabel(
                    pill.isMissed
                    ? "Log the missed dose of \(pill.name)"
                    : "Log \(pill.name)"
                )
            }
        } else {
            
            Image(systemName: "checkmark.circle")
                .font(.title)
                .foregroundColor(.textPrimary.opacity(0.1))
        }
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
                    formSystemImage: "pills.fill",
                    time: Date(),
                    period: .morning,
                    isTaken: false,
                    stockCount: 9,
                    lowStockThreshold: 10
                ),
                onToggle: { print("Toggle tapped") },
                onTapCard: { print("Card tapped") }
            )
            
            MedicationCardView(
                pill: PillDose(
                    medicationId: UUID(),
                    name: "Vitamin D",
                    dosage: 1,
                    formSystemImage: "capsule.fill",
                    time: Date().addingTimeInterval(3600),
                    period: .morning,
                    isTaken: true,
                    stockCount: 25,
                    lowStockThreshold: 10
                ),
                onToggle: { print("Toggle tapped") },
                onTapCard: { print("Card tapped") }
            )
            
            MedicationCardView(
                pill: PillDose(
                    medicationId: UUID(),
                    name: "Folic Acid",
                    dosage: 1,
                    formSystemImage: "pills.fill",
                    time: Date().addingTimeInterval(-3600),
                    period: .morning,
                    isTaken: false,
                    isSkipped: true,
                    stockCount: 25,
                    lowStockThreshold: 10
                ),
                onToggle: { print("Un-skip tapped") },
                onTapCard: { print("Card tapped") }
            )
            
            MedicationCardView(
                pill: PillDose(
                    medicationId: UUID(),
                    name: "Magnesium",
                    dosage: 2,
                    formSystemImage: "capsule.fill",
                    time: Date().addingTimeInterval(-7200),
                    period: .morning,
                    isTaken: false,
                    stockCount: 25,
                    lowStockThreshold: 10
                ),
                onToggle: { print("Late log tapped") },
                onTapCard: { print("Card tapped") }
            )
        }
        .padding()
    }
    .appTheme()
}
