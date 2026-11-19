//
//  CountRow.swift
//  Plekio
//
//  Created by Edward Gasparian on 19.11.2026.
//

import SwiftUI

/// A labelled number field for a pill count. Clamped to 0...9999,
/// so a paste can't store a negative or oversized value.
struct CountRow: View {

    let title: LocalizedStringResource
    let placeholder: LocalizedStringResource
    @Binding var value: Int
    let tint: Color
    let identifier: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.textPrimary)
            Spacer()
            TextField(String(localized: placeholder), value: clamped, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .foregroundColor(tint)
                .font(.headline)
                .padding(.trailing)
                .accessibilityIdentifier(identifier)
        }
    }

    private var clamped: Binding<Int> {
        Binding(get: { value }, set: { value = min(max($0, 0), 9999) })
    }
}
