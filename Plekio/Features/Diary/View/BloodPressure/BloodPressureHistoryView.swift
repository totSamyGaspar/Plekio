//
//  BloodPressureHistoryView.swift
//  Plekio
//
//  Created by Edward Gasparian on 14.09.2026.
//

import SwiftUI

/// The full blood-pressure history, grouped by day, shown as a sheet.
struct BloodPressureHistoryView: View {

    // MARK: - Properties

    let readings: [BloodPressureSnapshot]
    var onDelete: (BloodPressureSnapshot) -> Void
    var onDeleteAll: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var isClearConfirmationShown = false

    private struct DaySection: Identifiable {
        let id: Date
        let readings: [BloodPressureSnapshot]
    }

    /// Newest day first, newest reading first within each day.
    private var sections: [DaySection] {
        let calendar = Calendar.current
        return Dictionary(grouping: readings) { calendar.startOfDay(for: $0.measuredAt) }
            .map { day, items in
                DaySection(id: day, readings: items.sorted { $0.measuredAt > $1.measuredAt })
            }
            .sorted { $0.id > $1.id }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                if readings.isEmpty {
                    EmptyStateView(
                        icon: "heart.text.square",
                        title: "No readings yet"
                    )
                } else {
                    List {
                        ForEach(sections) { section in
                            Section {
                                ForEach(section.readings) { reading in
                                    row(reading)
                                        .listRowBackground(Color.appSurface)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                onDelete(reading)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                            .tint(.warningAccent)
                                        }
                                }
                            } header: {
                                Text(sectionTitle(for: section.id))
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.textSecondary)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Measurement history")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        isClearConfirmationShown = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.warningAccent)
                    }
                    .disabled(readings.isEmpty)
                    .opacity(readings.isEmpty ? 0.4 : 1)
                    .accessibilityLabel("Clear history")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.accentPrimary)
                }
            }
            .confirmationDialog(
                "Delete every reading?",
                isPresented: $isClearConfirmationShown,
                titleVisibility: .visible
            ) {
                Button("Delete all", role: .destructive) {
                    onDeleteAll()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The whole blood pressure history will be removed. This can't be undone.")
            }
            .appTheme()
        }
    }

    // MARK: - Helpers

    /// Fed day components, not elapsed time, so 00:30 reads "today" rather than "23 hours ago".
    private static let relativeDayFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .full
        return formatter
    }()

    /// "Today"/"Yesterday" (localized by Foundation), otherwise an abbreviated date.
    private func sectionTitle(for day: Date) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dayDelta = calendar.dateComponents([.day], from: day, to: today).day

        guard let dayDelta, dayDelta == 0 || dayDelta == 1 else {
            return day.formatted(date: .abbreviated, time: .omitted)
        }

        let named = Self.relativeDayFormatter.localizedString(from: DateComponents(day: -dayDelta))
        // Foundation returns it lower-cased; capitalize only the first character.
        return named.prefix(1).localizedUppercase + named.dropFirst()
    }

    // MARK: - Subviews

    private func row(_ reading: BloodPressureSnapshot) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(reading.formattedPressure)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.textPrimary)
                Text(reading.measuredAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.textSecondary)
            }

            Spacer(minLength: 8)

            if let pulse = reading.pulse {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundColor(.warningAccent)
                    Text("\(pulse) bpm")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.textSecondary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
