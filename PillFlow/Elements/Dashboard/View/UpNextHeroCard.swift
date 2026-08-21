//
//  UpNextHeroCard.swift
//  PillFlow
//
//  Created by Edward Gasparian on 19.06.2026.
//

import  SwiftUI

struct UpNextHeroCard: View {
    let pills: [PillDose]
    var onLogNow: () -> Void
    @State private var isPressed = false
    
    private var gradientColors: [Color] {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return [Color.mint, Color.teal]
        case 12..<18: return [Color.orange, Color.yellow]
        default:      return [Color.purple, Color.indigo]
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("UP NEXT TODAY")
                .font(.caption.weight(.heavy))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.25))
                .cornerRadius(20)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(pills) { pill in
                    HStack(spacing: 12) {
                        Image(systemName: pill.isTaken ? "checkmark.circle.fill" : "circle.dotted.circle")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(pill.isTaken ? .white.opacity(0.6) : .white)
                        
                        Text(pill.name)
                            .font(.system(size: pills.count > 1 ? 20 : 32, weight: .heavy, design: .serif))
                            .strikethrough(pill.isTaken)
                            .opacity(pill.isTaken ? 0.6 : 1.0)
                            .lineLimit(1)
                    }
                    .animation(.easeInOut(duration: 0.3), value: pill.isTaken)
                }
            }
            .foregroundColor(.white)
            
            Divider().background(Color.white.opacity(0.3))
            
            HStack {
                if let firstTime = pills.first?.time {
                    Text(firstTime.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 30, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                        isPressed = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        isPressed = false
                        onLogNow()
                    }
                }) {
                    Text(pills.count > 1 ? "LOG ALL" : "LOG NOW")
                        .font(.subheadline.weight(.heavy))
                        .foregroundColor(Color(red: 0.05, green: 0.3, blue: 0.2))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .cornerRadius(24)
                        .scaleEffect(isPressed ? 0.92 : 1.0)
                }
            }
        }
        .padding(24)
        .background(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
        .cornerRadius(32)
        .padding(.horizontal)
        .shadow(color: gradientColors.first!.opacity(0.3), radius: 20, x: 0, y: 15)
    }
}
