//
//  UpNextHeroCard.swift
//  Plekio
//
//  Created by Edward Gasparian on 19.06.2026.
//

import SwiftUI

struct UpNextHeroCard: View {

    // MARK: - Properties

    let pills: [PillDose]
    let selectedDate: Date
    let takenCount: Int
    let totalCount: Int
    var onLogNow: () -> Void

    // MARK: - Body

    var body: some View {
        HeroCard(title: "UP NEXT TODAY", date: selectedDate) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(pills) { pill in
                    HStack(spacing: 12) {
                        Image(systemName: pill.isTaken ? "checkmark.circle.fill" : "circle.dotted.circle")
                            .scaledFont(size: 18, relativeTo: .headline, weight: .bold)
                            .foregroundColor(pill.isTaken ? .white.opacity(0.6) : .white)
                            .animatedSymbol(pill.isTaken)

                        Text(pill.name)
                            .font(.system(size: pills.count > 1 ? 20 : 32, weight: .heavy, design: .serif))
                            .strikethrough(pill.isTaken)
                            .opacity(pill.isTaken ? 0.6 : 1.0)
                            .lineLimit(1)
                    }
                    .motion(.easeInOut(duration: 0.3), value: pill.isTaken)
                }
            }
            .foregroundColor(.white)

            Text("\(takenCount) of \(totalCount) doses logged")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))
                .animatedNumber(Double(takenCount))

            Divider().background(Color.white.opacity(0.3))

            HStack {
                if let firstTime = pills.first?.time {
                    Text(firstTime.formatted(date: .omitted, time: .shortened))
                        .scaledFont(size: 30, relativeTo: .title, weight: .bold, design: .default)
                        .foregroundColor(.white)
                }

                Spacer()

                Button(action: onLogNow) {
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
    }
}
