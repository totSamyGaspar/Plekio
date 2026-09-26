//
//  DiaryHeaderView.swift
//  Plekio
//
//  Created by Edward Gasparian on 14.09.2026.
//

import SwiftUI
import TipKit

/// The diary's title block with Compare and Add Entry actions.
struct DiaryHeaderView: View {

    // MARK: - Properties

    /// Zoom-transition sources for the sheets the parent screen presents.
    let compareSourceID: String
    let newEntrySourceID: String
    let transitionNamespace: Namespace.ID

    let onCompare: () -> Void

    private let compareTip = CompareProgressTip()
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
                Button {
                    compareTip.invalidate(reason: .actionPerformed)
                    onCompare()
                } label: {
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
                .matchedTransitionSource(id: compareSourceID, in: transitionNamespace)
                .popoverTip(compareTip, arrowEdge: .top)

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
                .matchedTransitionSource(id: newEntrySourceID, in: transitionNamespace)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal)
    }
}
