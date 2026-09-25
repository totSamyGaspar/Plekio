//
//  DiaryCheckInTagSection.swift
//  Plekio
//
//  Created by Edward Gasparian on 03.09.2026.
//

import SwiftUI

/// A titled chip grid with a row for adding custom tags.
struct DiaryTagSection: View {

    // MARK: - Properties

    let title: LocalizedStringKey
    let options: [String]
    /// Localized chip label for a stored value.
    let displayName: (String) -> String
    let isSelected: (String) -> Bool
    let accent: Color
    let prefix: String
    let inputPlaceholder: LocalizedStringKey
    let onToggle: (String) -> Void
    let onAddCustom: (String) -> Void

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption.weight(.heavy))
                .foregroundColor(.textSecondary)

            FlowLayout(spacing: 10) {
                ForEach(options, id: \.self) { option in
                    DiaryTagChip(
                        text: displayName(option),
                        isSelected: isSelected(option),
                        accent: accent,
                        prefix: prefix
                    ) {
                        onToggle(option)
                    }
                }
            }

            DiaryTagInputRow(placeholder: inputPlaceholder, onAdd: onAddCustom)
        }
    }
}
