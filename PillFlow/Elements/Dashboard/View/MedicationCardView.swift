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
    let isToday: Bool
    let onToggle: () -> Void
    let onTapCard: () -> Void
    
    // Reuse the shared color from Extensions/Theme.swift as the single source of truth.
    let cardDark = Color.cardDark
    
    @State private var uiImage: UIImage? = nil
    
    var body: some View {
        HStack(spacing: 16) {
            // MARK: - Icon / Image
            Group {
                if let uiImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: pill.formSystemImage)
                            .font(.title2)
                            .foregroundColor(.mint)
                    }
                }
            }
            .opacity(pill.isTaken ? 0.6 : 1.0)
            .onAppear { loadAsyncImage() }
            
            // MARK: - Info Text
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(pill.name)
                        .font(.headline.weight(.bold))
                        .foregroundColor(pill.isTaken ? .white.opacity(0.5) : .white)
                        .strikethrough(pill.isTaken)
                    
                    Text(pill.time.formatted(date: .omitted, time: .shortened))
                        .font(.caption2.weight(.heavy))
                        .foregroundColor(.mint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.mint.opacity(0.15))
                        .cornerRadius(8)
                }
                
                Text("\(pill.dosage) • Take with food")
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
            HStack(spacing: 8) {
                if isToday {
                    if pill.isTaken {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.mint)
                    } else if pill.isMissed {
                        Text("MISSED")
                            .font(.caption2.weight(.heavy))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.15))
                            .foregroundColor(.red)
                            .cornerRadius(6)
                    } else {
                        // Not yet due
                        Button(action: onToggle) {
                            Image(systemName: "checkmark.circle")
                                .font(.title)
                                .foregroundColor(.white.opacity(0.3))
                        }
                    }
                } else {
                    // Past or future days
                    if pill.isTaken {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.mint)
                    } else if pill.time < Date() {
                        Text("MISSED")
                            .font(.caption2.weight(.heavy))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.15))
                            .foregroundColor(.red)
                            .cornerRadius(6)
                    } else {
                        Image(systemName: "checkmark.circle")
                            .font(.title)
                            .foregroundColor(.white.opacity(0.1))
                    }
                }
            }
        }
        .padding()
        .background(cardDark)
        .cornerRadius(20)
        .onTapGesture {
            // Missed doses (past the 1-hour grace window) are locked: no modal,
            // no toggle. Within that window they're tappable like any other
            // upcoming dose.
            if isToday && !pill.isTaken && !pill.isMissed { onTapCard() }
        }
        // PillDose.id is regenerated on every fetch, which usually forces a
        // fresh card, but we don't rely on that alone: if SwiftUI reuses the
        // view, this reloads the photo from disk explicitly (same approach
        // as MedicationRowView).
        .onReceive(NotificationCenter.default.publisher(for: .databaseDidUpdate)) { _ in
            loadAsyncImage(force: true)
        }
    }

    private func loadAsyncImage(force: Bool = false) {
        // Cache lookup, disk read, and background decoding are centralized in
        // ImageCache.loadAsync (same pattern as MedicationRowView); we only
        // pass the medicationId since PillDose no longer carries the photo
        // blob. `force` isn't used by ImageCache.loadAsync itself but is kept
        // here to match MedicationRowView's signature.
        ImageCache.shared.loadAsync(for: pill.medicationId) { image in
            self.uiImage = image
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
                    dosage: "50mg",
                    formSystemImage: "pills.fill",
                    time: Date(),
                    period: .morning,
                    isTaken: false,
                    stockCount: 9,
                    lowStockThreshold: 10
                ),
                isToday: true,
                onToggle: { print("Toggle tapped") },
                onTapCard: { print("Card tapped") }
            )
            
            MedicationCardView(
                pill: PillDose(
                    medicationId: UUID(),
                    name: "Vitamin D",
                    dosage: "1 capsule",
                    formSystemImage: "capsule.fill",
                    time: Date().addingTimeInterval(3600),
                    period: .morning,
                    isTaken: true,
                    stockCount: 25,
                    lowStockThreshold: 10
                ),
                isToday: true,
                onToggle: { print("Toggle tapped") },
                onTapCard: { print("Card tapped") }
            )
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}

// MARK: - Extensions

extension Date {
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
}
