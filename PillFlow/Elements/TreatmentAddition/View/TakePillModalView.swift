//
//  TakePillModalView.swift
//  PillFlow
//
//  Created by Edward Gasparian on 02.05.2026.
//

//
//  TakePillModalView.swift
//  PillFlow
//

//import SwiftUI
//
//struct TakePillModalView: View {
//    @Environment(\.dismiss) private var dismiss
//    let pill: PillDose
//    var onTake: () -> Void
//    var onSkip: () -> Void
//    var onSnooze: () -> Void // Новое действие
//    
//    let cardDark = Color(red: 0.11, green: 0.13, blue: 0.19)
//    let bgDark = Color(red: 0.06, green: 0.08, blue: 0.12)
//    
//    var body: some View {
//        ZStack {
//            // 1. ФОНОВЫЙ БЛЮР
//            Color.black.opacity(0.4)
//                .ignoresSafeArea()
//                .onTapGesture { dismiss() }
//            
//            Rectangle()
//                .fill(.ultraThinMaterial)
//                .ignoresSafeArea()
//                .onTapGesture { dismiss() }
//            
//            // 2. ЦЕНТРАЛЬНАЯ КАРТОЧКА
//            VStack(spacing: 0) {
//                // MARK: - Header (Градиентный)
//                ZStack(alignment: .topTrailing) {
//                    LinearGradient(
//                        colors: [Color.blue.opacity(0.8), Color.neonMint.opacity(0.9)],
//                        startPoint: .topLeading,
//                        endPoint: .bottomTrailing
//                    )
//                    
//                    // Бейдж со временем
//                    HStack(spacing: 4) {
//                        Image(systemName: "clock")
//                        Text("Scheduled for \(pill.time.formatted(date: .omitted, time: .shortened))")
//                    }
//                    .font(.caption.weight(.bold))
//                    .foregroundColor(.white)
//                    .padding(.horizontal, 12)
//                    .padding(.vertical, 8)
//                    .background(Color.white.opacity(0.2))
//                    .clipShape(Capsule())
//                    .padding()
//                    
//                    HStack(spacing: 16) {
//                        // Иконка колокольчика
//                        ZStack {
//                            Circle()
//                                .fill(Color.white.opacity(0.2))
//                                .frame(width: 50, height: 50)
//                            Image(systemName: "bell.badge.fill")
//                                .font(.title3)
//                                .foregroundColor(.white)
//                        }
//                        
//                        VStack(alignment: .leading, spacing: 4) {
//                            Text("MEDICATION ALERT")
//                                .font(.caption.weight(.heavy))
//                                .foregroundColor(.white.opacity(0.8))
//                                .tracking(1.0)
//                            
//                            Text("Time for your Pill")
//                                .font(.title2.weight(.heavy))
//                                .foregroundColor(.white)
//                        }
//                        Spacer()
//                    }
//                    .padding(24)
//                    .padding(.top, 16)
//                }
//                
//                // MARK: - Content Body
//                VStack(spacing: 16) {
//                    // Карточка препарата
//                    HStack(spacing: 16) {
//                        ZStack {
//                            RoundedRectangle(cornerRadius: 16)
//                                .fill(Color.mint.opacity(0.1))
//                                .frame(width: 60, height: 60)
//                            Image(systemName: pill.formSystemImage)
//                                .font(.title)
//                                .foregroundColor(.neonMint)
//                        }
//                        
//                        VStack(alignment: .leading, spacing: 4) {
//                            Text(pill.name)
//                                .font(.title3.weight(.bold))
//                                .foregroundColor(.white)
//                            Text(pill.dosage)
//                                .font(.subheadline.weight(.semibold))
//                                .foregroundColor(.neonMint)
//                        }
//                        Spacer()
//                    }
//                    .padding(20)
//                    .background(cardDark)
//                    .cornerRadius(20)
//                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.05), lineWidth: 1))
//                    
//                    // Плашка инструкций
//                    HStack(alignment: .top, spacing: 12) {
//                        Image(systemName: "exclamationmark.circle")
//                            .foregroundColor(.yellow)
//                            .font(.title3)
//                        
//                        VStack(alignment: .leading, spacing: 4) {
//                            Text("Instructions:")
//                                .font(.subheadline.weight(.bold))
//                                .foregroundColor(.yellow)
//                            Text("Take with food in the \(pill.period.rawValue.lowercased())")
//                                .font(.subheadline)
//                                .foregroundColor(.white.opacity(0.8))
//                        }
//                        Spacer()
//                    }
//                    .padding(16)
//                    .background(Color.yellow.opacity(0.1))
//                    .cornerRadius(16)
//                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.yellow.opacity(0.3), lineWidth: 1))
//                    
//                    Spacer(minLength: 20)
//                    
//                    // MARK: - Action Buttons
//                    HStack(spacing: 12) {
//                        // Skip
//                        ActionButton(icon: "xmark", title: "Skip", color: .white, bgColor: cardDark) {
//                            onSkip()
//                            dismiss()
//                        }
//                        
//                        // Snooze
//                        ActionButton(icon: "clock", title: "Snooze 5m", color: .yellow, bgColor: Color.yellow.opacity(0.15)) {
//                            onSnooze()
//                            dismiss()
//                        }
//                        
//                        // Take Now
//                        Button(action: {
//                            onTake()
//                            dismiss()
//                        }) {
//                            VStack(spacing: 8) {
//                                Image(systemName: "checkmark")
//                                    .font(.title3.weight(.bold))
//                                Text("Take Now")
//                                    .font(.caption.weight(.bold))
//                            }
//                            .foregroundColor(bgDark)
//                            .frame(maxWidth: .infinity, maxHeight: .infinity)
//                            .background(Color.neonMint)
//                            .cornerRadius(16)
//                        }
//                    }
//                    .frame(height: 85)
//                }
//                .padding(24)
//                .background(bgDark)
//            }
//            .frame(maxWidth: 340) // ОГРАНИЧЕНИЕ ШИРИНЫ: именно это создает отступы и показывает блюр
//            .fixedSize(horizontal: false, vertical: true) // Карточка не растягивается на всю высоту
//            .cornerRadius(24)
//            .shadow(color: .black.opacity(0.6), radius: 40, x: 0, y: 20)
//        }
//    }
//}
//
//// Вспомогательная вьюшка для кнопок
//struct ActionButton: View {
//    let icon: String
//    let title: String
//    let color: Color
//    let bgColor: Color
//    let action: () -> Void
//    
//    var body: some View {
//        Button(action: action) {
//            VStack(spacing: 8) {
//                Image(systemName: icon)
//                    .font(.title3.weight(.bold))
//                    .foregroundColor(color)
//                Text(title)
//                    .font(.caption.weight(.bold))
//                    .foregroundColor(color.opacity(0.8))
//            }
//            .frame(maxWidth: .infinity, maxHeight: .infinity)
//            .background(bgColor)
//            .cornerRadius(16)
//        }
//    }
//}
//#Preview {
//    TakePillModalView(
//        pill: PillDose(
//            medicationId: UUID(), name: "Sertraline", dosage: "50mg",
//            formSystemImage: "pills.fill", time: Date(), period: .morning, isTaken: false
//        ),
//        onTake: {}, onSkip: {}, onSnooze: {}
//    )
//    .preferredColorScheme(.dark)
//}

import SwiftUI

struct TakePillModalView: View {
    @Environment(\.dismiss) private var dismiss
    
    // 1. ТЕПЕРЬ ПРИНИМАЕМ МАССИВ
    let pills: [PillDose]
    var onTake: () -> Void
    var onSkip: () -> Void
    var onSnooze: () -> Void
    
    let cardDark = Color(red: 0.11, green: 0.13, blue: 0.19)
    let bgDark = Color(red: 0.06, green: 0.08, blue: 0.12)
    
    var body: some View {
        ZStack {
            // ФОНОВЫЙ БЛЮР
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }
            
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }
            
            // ЦЕНТРАЛЬНАЯ КАРТОЧКА
            VStack(spacing: 0) {
                // MARK: - Header
                ZStack(alignment: .topTrailing) {
                    LinearGradient(
                        colors: [Color.blue.opacity(0.8), Color.neonMint.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    // Берем время из первой таблетки (оно у всех одинаковое)
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
                            
                            Text(pills.count > 1 ? "Time for your Pills" : "Time for your Pill")
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
                    
                    // 2. ДЕЛАЕМ СПИСОК ПРЕПАРАТОВ
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(pills) { pill in
                                HStack(spacing: 16) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.mint.opacity(0.1))
                                            .frame(width: 50, height: 50)
                                        Image(systemName: pill.formSystemImage)
                                            .font(.title2)
                                            .foregroundColor(.neonMint)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(pill.name)
                                            .font(.headline.weight(.bold))
                                            .foregroundColor(.white)
                                        Text("\(pill.dosage) • \(pill.period.rawValue.capitalized)")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(.neonMint)
                                    }
                                    Spacer()
                                }
                                .padding(16)
                                .background(cardDark)
                                .cornerRadius(16)
                            }
                        }
                    }
                    .frame(maxHeight: 220) // Ограничиваем высоту скролла, если таблеток много
                    
                    Spacer(minLength: 10)
                    
                    // MARK: - Action Buttons
                    HStack(spacing: 12) {
                        ActionButton(icon: "xmark", title: pills.count > 1 ? "Skip All" : "Skip", color: .white, bgColor: cardDark) {
                            onSkip()
                            dismiss()
                        }
                        
                        ActionButton(icon: "clock", title: "Snooze 5m", color: .yellow, bgColor: Color.yellow.opacity(0.15)) {
                            onSnooze()
                            dismiss()
                        }
                        
                        Button(action: {
                            onTake()
                            dismiss()
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: "checkmark")
                                    .font(.title3.weight(.bold))
                                Text(pills.count > 1 ? "Take All" : "Take Now")
                                    .font(.caption.weight(.bold))
                            }
                            .foregroundColor(bgDark)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.neonMint)
                            .cornerRadius(16)
                        }
                    }
                    .frame(height: 85)
                }
                .padding(24)
                .background(bgDark)
            }
            .frame(maxWidth: 340)
            .fixedSize(horizontal: false, vertical: true)
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.6), radius: 40, x: 0, y: 20)
        }
    }
}

struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let bgColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3.weight(.bold))
                    .foregroundColor(color)
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundColor(color.opacity(0.8))
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
            PillDose(medicationId: UUID(), name: "Sertraline", dosage: "50mg", formSystemImage: "pills.fill", time: Date(), period: .morning, isTaken: false, medicationImageData: nil, stockCount: 10, lowStockThreshold: 5),
            PillDose(medicationId: UUID(), name: "Vitamin D", dosage: "1 cap", formSystemImage: "capsule.fill", time: Date(), period: .morning, isTaken: false, medicationImageData: nil, stockCount: 10, lowStockThreshold: 5)
        ],
        onTake: {}, onSkip: {}, onSnooze: {}
    )
    .preferredColorScheme(.dark)
}
