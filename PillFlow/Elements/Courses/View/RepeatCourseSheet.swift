//
//  RepeatCourseSheet.swift
//  PillFlow
//
//  Created by Edward Gasparian on 07.09.2026.
//

import SwiftUI

/// Asks for the dates a finished course should run with the second time round.
///
/// It only collects and confirms — the copying itself belongs to the list view
/// model, so nothing here touches the database.
struct RepeatCourseSheet: View {
    let course: TreatmentCourse
    let onConfirm: (_ startDate: Date, _ endDate: Date) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var startDate: Date
    @State private var endDate: Date
    
    init(course: TreatmentCourse, onConfirm: @escaping (Date, Date) -> Void) {
        self.course = course
        self.onConfirm = onConfirm
        
        // The previous run's length is the best guess for the new one: the user
        // usually repeats the same treatment, just later.
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let previousLength = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: course.startDate),
            to: calendar.startOfDay(for: course.endDate)
        ).day ?? 0
        
        _startDate = State(initialValue: today)
        _endDate = State(
            initialValue: calendar.date(byAdding: .day, value: max(0, previousLength), to: today) ?? today
        )
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                Form {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(course.name)
                                .font(.headline.weight(.bold))
                                .foregroundColor(.textPrimary)
                            Text("Medications: \(course.medications.count)")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.textSecondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.appSurface)
                    
                    Section {
                        DatePicker("Start", selection: $startDate, displayedComponents: .date)
                            .foregroundColor(.textPrimary)
                        DatePicker("End", selection: $endDate,
                                   in: startDate..., displayedComponents: .date)
                        .foregroundColor(.textPrimary)
                    } header: {
                        Text("New dates")
                            .foregroundColor(.textSecondary)
                    } footer: {
                        Text("A new course with the same medications will be added to Active. The finished one stays in History.")
                            .foregroundColor(.textSecondary)
                    }
                    .listRowBackground(Color.appSurface)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Repeat course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start course") {
                        onConfirm(startDate, max(startDate, endDate))
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundColor(.accentPrimary)
                }
            }
        }
        // The end date follows the start when the user drags it past it, instead
        // of silently keeping a range the picker's `in:` bound already rejects.
        .onChange(of: startDate) { _, newValue in
            if endDate < newValue { endDate = newValue }
        }
    }
}
