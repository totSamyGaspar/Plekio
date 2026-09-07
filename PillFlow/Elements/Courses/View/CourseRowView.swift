//
//  CourseRowView.swift
//  PillFlow
//
//  Created by Edward Gasparian on 19.05.2026.
//

import SwiftUI

struct CourseRowView: View {
    private let viewModel: CourseRowViewModel
    let isHistory: Bool

    /// Set only for history rows. The card itself is not tappable there — a
    /// finished course has nothing left to edit — so this button is the one
    /// action it offers.
    let repeatAction: (() -> Void)?

    /// False while a copy of this course is already running. The button stays
    /// visible but inert, so the row explains why it can't be repeated instead of
    /// losing the control the user just looked for.
    let canRepeat: Bool

    @State private var animatedProgress: Double = 0.0

    init(
        course: TreatmentCourse,
        isHistory: Bool,
        canRepeat: Bool = true,
        repeatAction: (() -> Void)? = nil
    ) {
        self.viewModel = CourseRowViewModel(course: course)
        self.isHistory = isHistory
        self.canRepeat = canRepeat
        self.repeatAction = repeatAction
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            info
                // Only the finished-course information is dimmed: the Repeat
                // button below is live and must not read as disabled.
                .opacity(isHistory ? 0.7 : 1.0)

            if let repeatAction {
                Button(action: repeatAction) {
                    Label(repeatTitle, systemImage: canRepeat ? "arrow.clockwise" : "checkmark.circle")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(canRepeat ? .accentPrimary : .textTertiary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule().fill(
                            canRepeat
                            ? Color.accentPrimary.opacity(0.12)
                            : Color.textPrimary.opacity(0.05)
                        )
                    )
                    .overlay(
                        Capsule().stroke(
                            canRepeat
                            ? Color.accentPrimary.opacity(0.35)
                            : Color.textPrimary.opacity(0.10),
                            lineWidth: 1
                        )
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canRepeat)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityLabel(repeatAccessibilityLabel)
                .accessibilityHint(repeatAccessibilityHint)
            }
        }
        .padding(20)
        .background(Color.appSurface)
        .cornerRadius(24)
        .onAppear {
            animatedProgress = viewModel.daysProgress
        }
    }

    // Typed as LocalizedStringKey on purpose: a bare ternary of two string
    // literals leaves the Label/accessibility overloads to choose between
    // LocalizedStringKey and String, and picking String would silently ship the
    // English text to every language.
    private var repeatTitle: LocalizedStringKey {
        canRepeat ? "Repeat" : "Already active"
    }

    private var repeatAccessibilityLabel: LocalizedStringKey {
        canRepeat ? "Repeat course" : "Already active"
    }

    private var repeatAccessibilityHint: LocalizedStringKey {
        canRepeat
        ? "Starts this course again with new dates"
        : "This course is already running in Active"
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(viewModel.title)
                    .font(.headline.weight(.bold))
                    .foregroundColor(isHistory ? .textSecondary : .textPrimary)
                
                Spacer()
                
                if isHistory {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.accentPrimary)
                } else {
                    Text("Day \(viewModel.currentDayNumber) of \(viewModel.totalDays)")
                        .font(.caption.weight(.heavy))
                        .foregroundColor(Color.onAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.accentPrimary)
                        .cornerRadius(10)
                }
            }
            
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .foregroundColor(.accentPrimary.opacity(0.8))
                Text(viewModel.dateRangeText)
                    .font(.subheadline)
                    .foregroundColor(.textPrimary.opacity(0.7))
            }
            
            LinearProgressBar(progress: animatedProgress)
                .padding(.top, 4)
            
            HStack {
                Text("Medications: \(viewModel.medicationsCount)")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.textSecondary)
                
                Spacer()
                
                if isHistory {
                    Text("Course completed")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.accentPrimary)
                }
            }

        }
    }
}
