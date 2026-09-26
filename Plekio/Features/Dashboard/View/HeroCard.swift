//
//  HeroCard.swift
//  Plekio
//
//  Created by Edward Gasparian on 26.09.2026.
//

import SwiftUI

/// The frame shared by the Today hero cards: time-of-day gradient, a title chip and the date.
struct HeroCard<Content: View>: View {

    // MARK: - Properties

    let title: LocalizedStringKey
    var systemImage: String? = nil
    let date: Date
    /// Takes the whole proposed height; used when laid over another card of the same size.
    var fillsHeight = false
    @ViewBuilder let content: Content

    /// Time-of-day gradient based on the current hour.
    private var gradientColors: [Color] {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return [Color.heroMorningStart, Color.heroMorningEnd]
        case 12..<18: return [Color.heroNoonStart, Color.heroNoonEnd]
        default:      return [Color.heroEveningStart, Color.heroEveningEnd]
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            content
        }
        .frame(maxHeight: fillsHeight ? .infinity : nil, alignment: .topLeading)
        .padding(24)
        .background(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
        .cornerRadius(32)
        .padding(.horizontal)
    }

    // MARK: - Subviews

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 6) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
                .font(.caption.weight(.heavy))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.15))
                .cornerRadius(20)
                .foregroundColor(.white)

            Spacer(minLength: 0)

            Text(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(.subheadline.weight(.bold))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
        }
    }
}
