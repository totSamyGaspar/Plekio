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
    
    let cardDark = Color.cardDark
    
    var body: some View {
        HStack(spacing: 16) {
            // MARK: - Icon / Image
            
            MedicationPhotoView(medicationId: pill.medicationId, size: 48, cornerRadius: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(Color.white)
                    Image(systemName: pill.formSystemImage)
                        .font(.title2)
                        .foregroundColor(.neonMint)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
            .opacity(pill.isTaken ? 0.6 : 1.0)
            
            // MARK: - Info Text
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(pill.name)
                        .font(.headline.weight(.bold))
                        .foregroundColor(pill.isTaken ? .white.opacity(0.5) : .white)
                        .strikethrough(pill.isTaken)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    Text(pill.time.formatted(date: .omitted, time: .shortened))
                        .font(.caption2.weight(.heavy))
                        .foregroundColor(.neonMint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.neonMint.opacity(0.15))
                        .cornerRadius(8)
                }
                
                Text("\(pill.dosage) pcs")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                if let stock = pill.stockCount, stock <= pill.lowStockThreshold {
                    HStack(spacing: 4) {
                        Text("Stock: \(stock) remaining")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                        
                        Text("LOW")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.yellow.opacity(0.2))
                            .cornerRadius(4)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.yellow, lineWidth: 1))
                    }
                }
            }
            
            Spacer()
            
            // MARK: - Status Indicators
            
            statusIndicator
        }
        .padding()
        .background(cardDark)
        .cornerRadius(20)
        .onTapGesture {
            if pill.isLoggable && !pill.isTaken && !pill.isMissed { onTapCard() }
        }
    }
    
    // MARK: - Status Indicator
    
    @ViewBuilder
    private var statusIndicator: some View {
        if pill.isTaken {
            Button(action: onToggle) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.neonMint)
            }
            .buttonStyle(.plain)
            .disabled(!pill.isLoggable)
            .accessibilityLabel("Undo logging \(pill.name)")
        } else if pill.isLoggable {
            HStack(spacing: 8) {
                if pill.isMissed {
                    Text("MISSED")
                        .font(.caption2.weight(.heavy))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.15))
                        .foregroundColor(.red)
                        .cornerRadius(6)
                }
                
                Button(action: onToggle) {
                    Image(systemName: "checkmark.circle")
                        .font(.title)
                        .foregroundColor(pill.isMissed ? .red.opacity(0.75) : .white.opacity(0.3))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    pill.isMissed
                    ? "Log the missed dose of \(pill.name)"
                    : "Log \(pill.name)"
                )
            }
        } else {
            
            Image(systemName: "checkmark.circle")
                .font(.title)
                .foregroundColor(.white.opacity(0.1))
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(red: 0.06, green: 0.08, blue: 0.12).ignoresSafeArea()
        
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
    .preferredColorScheme(.dark)
}
