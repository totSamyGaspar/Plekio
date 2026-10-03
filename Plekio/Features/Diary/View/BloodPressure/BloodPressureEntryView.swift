//
//  BloodPressureEntryView.swift
//  Plekio
//
//  Created by Edward Gasparian on 30.08.2026.
//

import SwiftUI

/// Form for one blood-pressure reading.
struct BloodPressureEntryView: View {

    // MARK: - Properties

    @Environment(\.dismiss) private var dismiss

    var onSave: (_ measuredAt: Date, _ systolic: Int, _ diastolic: Int, _ pulse: Int?) -> Void

    @State private var measuredAt = Date()
    @State private var systolicText = ""
    @State private var diastolicText = ""
    @State private var pulseText = ""
    @State private var isCalendarShown = false

    private var systolic: Int? { Int(systolicText) }
    private var diastolic: Int? { Int(diastolicText) }
    private var pulse: Int? { Int(pulseText) }

    /// Same rule check BloodPressureLogging applies on write. Nil while a field is empty.
    private var issue: BloodPressureRules.Issue? {
        guard let systolic, let diastolic else { return nil }
        return BloodPressureRules.issue(
            systolic: systolic, diastolic: diastolic, pulse: pulse,
            measuredAt: measuredAt, now: latestSelectableDate
        )
    }

    /// Blocked rather than clamped: a silently corrected 999 → 300 would look like a misread monitor.
    private var canSave: Bool {
        systolic != nil && diastolic != nil && issue == nil
    }

    /// Systolic not above diastolic. Separate from `canSave` so the form can explain the disabled Save.
    private var isInverted: Bool {
        issue == .inverted
    }

    /// Upper bound of every picker: a reading can't be in the future.
    private var latestSelectableDate: Date { Date() }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                Form {
                    Section {
                        dateRow

                        if isCalendarShown {
                            DatePicker(
                                "Measured at",
                                selection: $measuredAt,
                                in: ...latestSelectableDate,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.graphical)
                            .labelsHidden()
                            .tint(.accentPrimary)
                        }
                    }
                    .listRowBackground(Color.appSurface)

                    Section {
                        numberRow(
                            "Systolic",
                            text: $systolicText,
                            unit: "mmHg",
                            placeholder: "120",
                            range: BloodPressureRules.systolicRange,
                            isFlagged: isInverted
                        )
                        numberRow(
                            "Diastolic",
                            text: $diastolicText,
                            unit: "mmHg",
                            placeholder: "80",
                            range: BloodPressureRules.diastolicRange,
                            isFlagged: isInverted
                        )
                        // Optional: not every monitor reports a pulse.
                        numberRow(
                            "Pulse",
                            text: $pulseText,
                            unit: "bpm",
                            placeholder: "70",
                            range: BloodPressureRules.pulseRange
                        )
                    } footer: {
                        if isInverted {
                            Text("Systolic must be higher than diastolic.")
                                .foregroundColor(.warningAccent)
                        } else {
                            Text("A value outside its range can't be saved. Pulse is optional — leave it empty if your monitor doesn't show one.")
                                .foregroundColor(.textSecondary)
                        }
                    }
                    .listRowBackground(Color.appSurface)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New reading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.textPrimary.opacity(0.7))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        guard let systolic, let diastolic else { return }
                        onSave(measuredAt, systolic, diastolic, pulse)
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(canSave ? .accentPrimary : .textTertiary)
                    .disabled(!canSave)
                }
            }
            .appTheme()
        }
    }

    // MARK: - Date

    /// Day and month only; the compact DatePicker's label would always show the year.
    private var dateRow: some View {
        HStack(spacing: 12) {
            Text("Measured at")
                .foregroundColor(.textPrimary)

            Spacer(minLength: 0)

            Button {
                withMotion(.snappy) { isCalendarShown.toggle() }
            } label: {
                Text(measuredAt.formatted(.dateTime.day().month(.abbreviated)))
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(isCalendarShown ? .accentPrimary : .textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.textPrimary.opacity(0.08))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Measurement date")
            .accessibilityValue(measuredAt.formatted(date: .long, time: .omitted))

            DatePicker(
                "Measured at",
                selection: $measuredAt,
                in: ...latestSelectableDate,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
        }
    }

    // MARK: - Number input

    /// Empty isn't flagged, so untouched fields aren't red when the form opens.
    private func isOutOfRange(_ text: String, _ range: ClosedRange<Int>) -> Bool {
        guard !text.isEmpty else { return false }
        guard let value = Int(text) else { return true }
        return !range.contains(value)
    }

    private func numberRow(
        _ title: LocalizedStringKey,
        text: Binding<String>,
        unit: LocalizedStringKey,
        placeholder: String,
        range: ClosedRange<Int>,
        isFlagged: Bool = false
    ) -> some View {
        let isInvalid = isFlagged || isOutOfRange(text.wrappedValue, range)

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundColor(.textPrimary)
                // Verbatim: two numbers and a dash need no translation.
                Text(verbatim: "\(range.lowerBound)–\(range.upperBound)")
                    .font(.caption2)
                    .foregroundColor(isInvalid ? .warningAccent : .textTertiary)
            }

            Spacer(minLength: 8)

            // The title isn't drawn (the prompt is); VoiceOver reads it.
            TextField(title, text: text, prompt: Text(verbatim: placeholder))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .foregroundColor(isInvalid ? .warningAccent : .textPrimary)
                .frame(maxWidth: 80)
            // Digits only, max 3: a number pad still accepts pasted text.
                .onChange(of: text.wrappedValue) { _, newValue in
                    let cleaned = String(newValue.filter(\.isNumber).prefix(3))
                    if cleaned != newValue { text.wrappedValue = cleaned }
                }

            Text(unit)
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(
            isInvalid
            ? Text("Outside the allowed range")
            : Text(verbatim: text.wrappedValue)
        )
    }
}
