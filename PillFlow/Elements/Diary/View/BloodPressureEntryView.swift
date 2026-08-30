//
//  BloodPressureEntryView.swift
//  PillFlow
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

    private var systolic: Int? { Int(systolicText) }
    private var diastolic: Int? { Int(diastolicText) }
    private var pulse: Int? { Int(pulseText) }

    /// Saving is blocked rather than silently corrected. The database clamps too,
    /// but a reading quietly turned from 999 into 260 would look like the app
    /// misread the monitor.
    private var canSave: Bool {
        guard let systolic, let diastolic else { return false }
        guard BloodPressureReading.systolicRange.contains(systolic),
              BloodPressureReading.diastolicRange.contains(diastolic) else { return false }
        if let pulse, !BloodPressureReading.pulseRange.contains(pulse) { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                Form {
                    Section {
                        DatePicker("Measured at", selection: $measuredAt)
                            .foregroundColor(.textPrimary)
                    }
                    .listRowBackground(Color.appSurface)

                    Section {
                        numberRow("Systolic", text: $systolicText, unit: "mmHg")
                        numberRow("Diastolic", text: $diastolicText, unit: "mmHg")
                        // Optional: not every monitor reports a pulse.
                        numberRow("Pulse", text: $pulseText, unit: "bpm")
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

    private func numberRow(
        _ title: LocalizedStringKey,
        text: Binding<String>,
        unit: LocalizedStringKey
    ) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.textPrimary)
            Spacer()
            TextField("", text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .foregroundColor(.textPrimary)
                .frame(maxWidth: 80)
            Text(unit)
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
    }
}
