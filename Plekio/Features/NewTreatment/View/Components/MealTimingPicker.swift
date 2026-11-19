//
//  MealTimingPicker.swift
//  Plekio
//
//  Created by Edward Gasparian on 19.11.2026.
//

import SwiftUI

/// Meal timing as a row of chips; nil reads "Doesn't matter".
struct MealTimingPicker: View {

    @Binding var selection: MealTiming?

    var body: some View {
        FlowLayout(spacing: 8) {
            chip(nil)
            ForEach(MealTiming.allCases, id: \.self) { chip($0) }
        }
        .padding(.vertical, 6)
        .sensoryFeedback(.selection, trigger: selection)
    }

    /// `.plain`: in a Form row a tap would otherwise trigger every button in it.
    private func chip(_ timing: MealTiming?) -> some View {
        let isSelected = selection == timing
        return Button {
            selection = timing
        } label: {
            Group {
                if let timing {
                    Text(timing.title)
                } else {
                    Text("Doesn't matter")
                }
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentPrimary : Color.textPrimary.opacity(0.06))
            .foregroundColor(isSelected ? .onAccent : .textPrimary.opacity(0.8))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
