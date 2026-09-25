//
//  RepeatCourseSheet.swift
//  Plekio
//
//  Created by Edward Gasparian on 07.09.2026.
//

import SwiftUI

/// Collects new dates for repeating a finished course; the copy is made by the caller.
struct RepeatCourseSheet: View {

    // MARK: - Properties

    let course: CourseSnapshot
    let onConfirm: (_ startDate: Date, _ endDate: Date) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var startDate: Date
    @State private var endDate: Date

    // MARK: - Init

    init(course: CourseSnapshot, onConfirm: @escaping (Date, Date) -> Void) {
        self.course = course
        self.onConfirm = onConfirm

        // Default to the previous run's length, starting today.
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

    // MARK: - Body

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
        // Keep end >= start; the picker's `in:` bound alone doesn't update it.
        .onChange(of: startDate) { _, newValue in
            if endDate < newValue { endDate = newValue }
        }
    }
}
