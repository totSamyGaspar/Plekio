//
//  MedicationCardView.swift
//  PillFlow
//
//  Created by Edward Gasparian on 20.05.2026.
//

import SwiftUI

struct MedicationCardView: View {
    let pill: PillDose
    let isToday: Bool
    let onToggle: () -> Void
    let onTapCard: () -> Void
    
    let cardDark = Color(red: 0.11, green: 0.13, blue: 0.19)
    
    @State private var uiImage: UIImage? = nil
    
    var body: some View {
        HStack(spacing: 16) {
            // MARK: - Icon / Image
            Group {
                if let uiImage = ImageCache.shared.image(for: pill.medicationId, data: pill.medicationImageData) {
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
                        // Таблетка выпита
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.mint)
                    } else if pill.isMissed {
                        // Таблетка пропущена
                        Text("MISSED")
                            .font(.caption2.weight(.heavy))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.15))
                            .foregroundColor(.red)
                            .cornerRadius(6)
                    } else {
                        // Обычное состояние (время еще не пришло)
                        Button(action: onToggle) {
                            Image(systemName: "checkmark.circle")
                                .font(.title)
                                .foregroundColor(.white.opacity(0.3))
                        }
                    }
                } else {
                    // Прошлые или будущие дни
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
            if isToday && !pill.isTaken { onTapCard() }
        }
    }
    
    private func loadAsyncImage() {
        // 1. Проверяем наличие в кеше
        if let cachedImage = ImageCache.shared.get(forKey: pill.medicationId) {
            self.uiImage = cachedImage
            return
        }
        
        guard let imageData = pill.medicationImageData else { return }
        
        // 2. Если в кеше нет, декодируем
        DispatchQueue.global(qos: .userInitiated).async {
            if let decodedImage = UIImage(data: imageData) {
                // 3. Сохраняем в кеш
                ImageCache.shared.set(decodedImage, forKey: pill.medicationId)
                
                DispatchQueue.main.async {
                    self.uiImage = decodedImage
                }
            }
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
                    medicationImageData: nil,
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
                    medicationImageData: nil,
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
