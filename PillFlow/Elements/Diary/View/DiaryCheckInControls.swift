//
//  DiaryCheckInControls.swift
//  PillFlow
//
//  The small building blocks of the check-in form.
//
//  None of them know about the view model: they take the value they show and
//  the action they perform, which is what makes them safe to move around and
//  reuse. They lived as private methods on DiaryCheckInView, where a 775-line
//  type made it hard to see that two of the sections were the same markup
//  twice over.
//

import SwiftUI

/// A titled box around one value — the CHECK-IN DATE and TIME pair.
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
            // Centred, not leading: the compact DatePicker renders as a pill
            // that hugs its text, so aligning it leading left it floating in
            // the corner of a much wider box.
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.appSurface)
                .cornerRadius(12)
        }
    }
}

/// A date or time value as plain text, tappable across the whole field.
///
/// The compact `DatePicker` paints its own grey capsule and SwiftUI offers no
/// way to turn that off. Hiding it under a transparent overlay does not work
/// either — it stops receiving touches — so the value is drawn as text and the
/// picker moved into a popover this opens.
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

/// An icon, a title, a slider and its three scale labels.
struct DiarySliderRow: View {
    let icon: String
    let iconColor: Color
    let title: LocalizedStringKey
    /// LocalizedStringResource, not LocalizedStringKey, because this one is not
    /// written here: it comes from DiaryEntryDraft, which is Foundation-only.
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
                // Three labels share one row ("0 (None) / 5 (Manageable) / 10 (Severe)");
                // the middle one is noticeably longer in German and Romanian.
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

/// The "type your own + Add" row under a chip grid.
///
/// Clearing the field is part of adding, so it belongs here rather than in each
/// caller's closure — that was the one line the two copies of this row could
/// have disagreed on.
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
