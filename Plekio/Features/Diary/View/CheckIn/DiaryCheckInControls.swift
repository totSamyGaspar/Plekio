//
//  DiaryCheckInControls.swift
//  Plekio
//
//  Created by Edward Gasparian on 03.09.2026.
//

import SwiftUI

// MARK: - DiaryLabeledField

/// A titled box around one value, e.g. the check-in date and time.
struct DiaryLabeledField<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2.weight(.heavy))
                .foregroundColor(.textSecondary)
                .tracking(0.5)
            content
            // Centred: a compact DatePicker hugs its text and would float in the corner.
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.appSurface)
                .cornerRadius(12)
        }
    }
}

// MARK: - DiaryValueButton

/// A date or time value as plain text that opens a picker popover.
/// The compact DatePicker's grey capsule can't be removed, and a transparent overlay stops receiving touches.
struct DiaryValueButton: View {
    let text: String
    let label: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(text)
    }
}

// MARK: - DiarySliderRow

/// An icon, a title, a slider and its three scale labels.
struct DiarySliderRow: View {
    let icon: String
    let iconColor: Color
    let title: LocalizedStringKey
    /// A resource, not a key: it comes from DiaryEntryDraft, which is Foundation-only.
    let trailingLabel: LocalizedStringResource
    @Binding var value: Double
    let range: ClosedRange<Double>
    let tint: Color
    let minLabel: LocalizedStringKey
    let midLabel: LocalizedStringKey
    let maxLabel: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: icon).foregroundColor(iconColor)
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.textPrimary)
                }
                Spacer()
                Text(trailingLabel)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            Slider(value: $value, in: range, step: 1)
                .tint(tint)
            HStack {
                // Three labels share one row; some translations need two lines.
                Text(minLabel).font(.caption2).foregroundColor(.textSecondary)
                    .lineLimit(2).minimumScaleFactor(0.9)
                Spacer(minLength: 4)
                Text(midLabel).font(.caption2).foregroundColor(.textSecondary)
                    .lineLimit(2).minimumScaleFactor(0.9)
                Spacer(minLength: 4)
                Text(maxLabel).font(.caption2).foregroundColor(.textSecondary)
                    .lineLimit(2).minimumScaleFactor(0.9)
            }
        }
    }
}

// MARK: - DiaryTagChip

/// One selectable chip in the symptom and milestone grids.
struct DiaryTagChip: View {
    let text: String
    let isSelected: Bool
    let accent: Color
    let prefix: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(isSelected ? "✓" : prefix)
                Text(text)
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? accent.opacity(0.9) : Color.appSurface)
            .foregroundColor(isSelected ? Color.onAccent : .textPrimary.opacity(0.8))
            .overlay(
                Capsule().stroke(isSelected ? Color.clear : Color.textPrimary.opacity(0.1), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - DiaryTagInputRow

/// The "type your own + Add" row under a chip grid. Clears the field after adding.
struct DiaryTagInputRow: View {
    let placeholder: LocalizedStringKey
    let onAdd: (String) -> Void

    @State private var text = ""

    var body: some View {
        HStack(spacing: 10) {
            TextField(placeholder, text: $text)
                .foregroundColor(.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.appSurface)
                .cornerRadius(12)

            Button("Add") {
                onAdd(text)
                text = ""
            }
            .font(.subheadline.weight(.bold))
            .foregroundColor(Color.onAccent)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxHeight: .infinity)
            .background(Color.accentPrimary)
            .cornerRadius(12)
            .contentShape(Rectangle())
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
