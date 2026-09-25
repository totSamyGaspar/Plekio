//
//  DiaryHeaderView.swift
//  Plekio
//
//  Created by Edward Gasparian on 14.09.2026.
//

import SwiftUI

/// The diary's title block with Compare and Add Entry actions.
struct DiaryHeaderView: View {

    // MARK: - Properties

    /// Zoom-transition source for the comparison sheet, which is presented by the parent screen.
    let transitionSourceID: String
    let transitionNamespace: Namespace.ID

    let onCompare: () -> Void
    let onAddEntry: () -> Void

    // MARK: - Body

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
