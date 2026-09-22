//
//  CoursePreview.swift
//  Plekio
//

import SwiftUI

/// Slide 1: what adding a course looks like once it is done.
///
/// Sample content is deliberately concrete — a real drug name, real times, a
/// real count. A card full of "Medication 1" reads as a placeholder and
/// teaches nothing about the product.
struct CoursePreview: View {

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "pills.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.accentPrimary)
                    .frame(width: 44, height: 44)
                    .background(Color.accentPrimary.opacity(0.14))
                    .clipShape(.rect(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "Ibuprofen")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    Text("Every day")
                        .font(.system(size: 13))
                        .foregroundColor(.textSecondary)
                }

                Spacer(minLength: 0)

                Text(verbatim: "2")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.accentPrimary)
            }

            divider

            VStack(alignment: .leading, spacing: 9) {
                OnboardingCaption(text: "Intake Time")
                HStack(spacing: 7) {
                    ForEach(["08:00", "14:00", "20:00"], id: \.self) { time in
                        Text(verbatim: time)
                            .font(.system(size: 13))
                            .foregroundColor(.textPrimary)
                            .onboardingChip()
                    }
                }
            }

            divider

            HStack {
                Text("Left in pack")
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
                Spacer(minLength: 0)
                Text(verbatim: "30")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textPrimary)
            }
        }
        .frame(width: 306)
        .onboardingCard(18, radius: 26)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.textPrimary.opacity(0.08))
            .frame(height: 1)
    }
}

#Preview {
    CoursePreview()
        .padding(40)
        .background(Color.appBackground)
}
