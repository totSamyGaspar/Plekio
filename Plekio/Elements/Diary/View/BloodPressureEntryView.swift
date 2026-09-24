//
//  BloodPressureEntryView.swift
//  Plekio
//

import SwiftUI

/// Form for one blood-pressure reading.
struct BloodPressureEntryView: View {
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
    
    /// Saving is blocked rather than silently corrected. The database clamps too,
    /// but a reading quietly turned from 999 into 300 would look like the app
    /// misread the monitor.
    private var canSave: Bool {
        guard let systolic, let diastolic else { return false }
        guard BloodPressureReading.systolicRange.contains(systolic),
              BloodPressureReading.diastolicRange.contains(diastolic) else { return false }
        if let pulse, !BloodPressureReading.pulseRange.contains(pulse) { return false }
        return BloodPressureReading.isOrdered(systolic: systolic, diastolic: diastolic)
    }

    /// Both numbers in range and still not a reading. Kept apart from `canSave`
    /// because the form has to say so, not just go quiet: a Save button that
    /// dims with every field filled in looks broken.
    private var isInverted: Bool {
        guard let systolic, let diastolic else { return false }
        return !BloodPressureReading.isOrdered(systolic: systolic, diastolic: diastolic)
    }
    
    /// A measurement cannot have happened later than now, and the reading is
    /// typed in right after it is taken — so "now" is both the default and the
    /// upper bound of every picker here.
    private var latestSelectableDate: Date { Date() }
    
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
                            range: BloodPressureReading.systolicRange,
                            isFlagged: isInverted
                        )
                        numberRow(
                            "Diastolic",
                            text: $diastolicText,
                            unit: "mmHg",
                            placeholder: "80",
                            range: BloodPressureReading.diastolicRange,
                            isFlagged: isInverted
                        )
                        // Optional: not every monitor reports a pulse.
                        numberRow(
                            "Pulse",
                            text: $pulseText,
                            unit: "bpm",
                            placeholder: "70",
                            range: BloodPressureReading.pulseRange
                        )
                    } footer: {
                        // The specific complaint replaces the general hint
                        // exactly when there is one, rather than stacking under it.
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
    
    /// The year is deliberately absent: a reading is entered the same day it is
    /// taken, and the compact DatePicker's own label always carries the year.
    /// Hence a plain button showing day and month, with the calendar underneath.
    private var dateRow: some View {
        HStack(spacing: 12) {
            Text("Measured at")
                .foregroundColor(.textPrimary)
            
            Spacer(minLength: 0)
            
            Button {
                withAnimation(.snappy) { isCalendarShown.toggle() }
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
    
    /// Empty is not an error: an untouched field has nothing to complain about
    /// yet, and colouring it red the moment the form opens is just noise.
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
                // Just two numbers and a dash — the same in every language the
                // app ships in, so it is built here instead of being translated.
                Text(verbatim: "\(range.lowerBound)–\(range.upperBound)")
                    .font(.caption2)
                    .foregroundColor(isInvalid ? .warningAccent : .textTertiary)
            }
            
            Spacer(minLength: 8)
            
            TextField("", text: text, prompt: Text(verbatim: placeholder))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .foregroundColor(isInvalid ? .warningAccent : .textPrimary)
                .frame(maxWidth: 80)
            // Digits only, and never more than the widest bound needs: a
            // number pad still accepts a paste, and a 6-digit value would
            // only ever be rejected on save.
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
