//
//  DiaryCheckInTagSection.swift
//  PillFlow
//
//  Symptoms and milestones were the same forty lines twice: a heading, a flow
//  of chips, and a field to add your own. Only the wording, the accent colour,
//  the chip prefix and the handlers differed — so those are the parameters.
//

import SwiftUI

struct DiaryTagSection: View {
    let title: LocalizedStringKey
    let options: [String]
    /// Chip labels are localized separately from the stored value, so the
    /// section is handed the lookup rather than guessing at it.
    let displayName: (String) -> String
    let isSelected: (String) -> Bool
    let accent: Color
    let prefix: String
    let inputPlaceholder: LocalizedStringKey
    let onToggle: (String) -> Void
    let onAddCustom: (String) -> Void
    
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
