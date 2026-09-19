//
//  DiaryHeaderView.swift
//  PillFlow
//

import SwiftUI

/// The diary's title block and its two actions.
///
/// A view rather than a `private var` on DiaryView: it needs the screen's state
/// only through the two closures, so pulling it out costs four parameters and
/// buys a piece that can be looked at on its own.
struct DiaryHeaderView: View {

    /// The zoom transition the comparison sheet grows out of. Passed through
    /// rather than owned here, because the sheet that matches it lives on the
    /// screen above.
    let transitionSourceID: String
    let transitionNamespace: Namespace.ID

    let onCompare: () -> Void
    let onAddEntry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Daily Health & Mood Diary")
                    .scaledFont(size: 30, relativeTo: .title, weight: .heavy, design: .serif)
                    .foregroundColor(.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("· \(Date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }

            Text("Track how your body responds to your regimen, log symptoms, record daily energy levels, and compare progress photos over time.")
                .font(.subheadline)
                .foregroundColor(.textSecondary)

            HStack(spacing: 12) {
                Button(action: onCompare) {
                    Label("Compare Progress", systemImage: "arrow.triangle.2.circlepath")
                        .labelStyle(.centered)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.textPrimary.opacity(0.8))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.appSurface)
                        .cornerRadius(14)
                }
                .buttonStyle(.plain)
                .matchedTransitionSource(id: transitionSourceID, in: transitionNamespace)

                Button(action: onAddEntry) {
                    Label("Add New Entry", systemImage: "plus")
                        .labelStyle(.centered)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(Color.onAccent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.accentPrimary)
                        .cornerRadius(14)
                }
                .buttonStyle(.plain)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal)
    }
}
