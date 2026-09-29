//
//  TimeOfDayRows.swift
//  Plekio
//
//  Created by Edward Gasparian on 29.09.2026.
//

import SwiftUI

/// Editable wall-clock times for a Form section. Never fewer than one: with no
/// time the medication or reminder would never fire.
struct TimeOfDayRows: View {

    @Binding var minutes: [Int]
    var maxCount = Int.max
    /// The row's label by index.
    let title: (Int) -> Text

    var body: some View {
        // Iterates the array (not 0..<count) and bounds-checks every access:
        // indices go stale while rows are deleted.
        ForEach(Array(minutes.enumerated()), id: \.offset) { index, _ in
            DatePicker(selection: minute(at: index).timeOfDay, displayedComponents: .hourAndMinute) {
                title(index)
            }
            .foregroundColor(.textPrimary)
        }
        .onDelete { offsets in
            guard minutes.count > offsets.count else { return }
            minutes.remove(atOffsets: offsets)
        }

        if minutes.count < maxCount {
            Button(action: addTime) {
                Label("Add time", systemImage: "plus.circle.fill")
                    .foregroundColor(.accentPrimary)
            }
        }
    }

    private func minute(at index: Int) -> Binding<Int> {
        Binding(
            get: { minutes.indices.contains(index) ? minutes[index] : 0 },
            set: { newValue in
                guard minutes.indices.contains(index) else { return }
                minutes[index] = newValue
            }
        )
    }

    /// Four hours after the last time, wrapping past midnight.
    private func addTime() {
        let last = minutes.last ?? 0
        minutes.append((last + 4 * 60) % (24 * 60))
    }
}
