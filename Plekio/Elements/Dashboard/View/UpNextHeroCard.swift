//
//  UpNextHeroCard.swift
//  Plekio
//
//  Created by Edward Gasparian on 19.06.2026.
//

import  SwiftUI

struct UpNextHeroCard: View {
    let pills: [PillDose]
    let selectedDate: Date
    let takenCount: Int
    let totalCount: Int
    var onLogNow: () -> Void
    
    private var gradientColors: [Color] {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return [Color.heroMorningStart, Color.heroMorningEnd]
        case 12..<18: return [Color.heroNoonStart, Color.heroNoonEnd]
        default:      return [Color.heroEveningStart, Color.heroEveningEnd]
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                Text("UP NEXT TODAY")
                    .font(.caption.weight(.heavy))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.15))
                    .cornerRadius(20)
                    .foregroundColor(.white)
                
                Spacer(minLength: 0)
                
                Text(selectedDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(pills) { pill in
                    HStack(spacing: 12) {
                        Image(systemName: pill.isTaken ? "checkmark.circle.fill" : "circle.dotted.circle")
                            .scaledFont(size: 18, relativeTo: .headline, weight: .bold)
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
            
            Text("\(takenCount) of \(totalCount) doses logged")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))
            
            Divider().background(Color.white.opacity(0.3))
            
            HStack {
                if let firstTime = pills.first?.time {
                    Text(firstTime.formatted(date: .omitted, time: .shortened))
                        .scaledFont(size: 30, relativeTo: .title, weight: .bold, design: .default)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onLogNow()
                } label: {
                    Text(pills.count > 1 ? "LOG ALL" : "LOG NOW")
                        .font(.subheadline.weight(.heavy))
                        .foregroundColor(Color(red: 0.05, green: 0.3, blue: 0.2))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .cornerRadius(24)
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(24)
        .background(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
        .cornerRadius(32)
        .padding(.horizontal)
    }
}

private struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: configuration.isPressed)
    }
}
