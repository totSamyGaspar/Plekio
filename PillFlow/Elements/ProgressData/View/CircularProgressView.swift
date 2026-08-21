//
//  CircularProgressView.swift
//  PillFlow
//
//  Created by Edward Gasparian on 06.05.2026.
//

import SwiftUI

struct CircularProgressView: View {
    let progress: Double // от 0.0 до 1.0
    let goal: Int // Цель в процентах, например 90
    
    // Градиент для заполненной части
    let ringGradient = LinearGradient(
        colors: [Color.mint, Color.teal],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        ZStack {
            // Фоновое кольцо (полупрозрачный изумрудный, чтобы круто смотрелось на синем)
            Circle()
                .stroke(Color.mint.opacity(0.2), lineWidth: 16)
            
            // Заполненное кольцо
            Circle()
                .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                .stroke(ringGradient, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.7), value: progress)
            
            // Текст внутри кольца
            VStack(spacing: 2) {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 48, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                
                Text("GOAL \(goal)%")
                    .font(.caption.weight(.heavy))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(20)
    }
}
