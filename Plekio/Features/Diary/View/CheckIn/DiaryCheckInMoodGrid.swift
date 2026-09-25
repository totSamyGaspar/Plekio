//
//  DiaryCheckInMoodGrid.swift
//  Plekio
//
//  Created by Edward Gasparian on 03.09.2026.
//

import SwiftUI

/// The "overall mood today" grid.
struct DiaryMoodGrid: View {

    // MARK: - Properties

    @Binding var selection: DiaryMood

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("OVERALL MOOD TODAY")
                    .font(.caption.weight(.heavy))
                    .foregroundColor(.textSecondary)
                    .tracking(0.5)
                Spacer()
                Text("SELECT DOMINANT MOOD")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.accentPrimary.opacity(0.8))
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(DiaryMood.allCases) { mood in
                    card(for: mood)
                }
            }
        }
    }

    // MARK: - Subviews

    private func card(for mood: DiaryMood) -> some View {
        let isSelected = selection == mood
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selection = mood
            }
        } label: {
            HStack(spacing: 12) {
                Text(mood.emoji).font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(mood.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.textPrimary)
                    Text("Score: \(mood.score)/5")
                        .font(.caption2)
                        .foregroundColor(.textSecondary)
                }
                Spacer()
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.accentPrimary.opacity(0.15) : Color.appSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.accentPrimary : Color.textPrimary.opacity(0.06), lineWidth: isSelected ? 1.5 : 1)
            )
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
