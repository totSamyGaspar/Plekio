//
//  CourseRowView.swift
//  Plekio
//
//  Created by Edward Gasparian on 19.05.2026.
//

import SwiftUI

struct CourseRowView: View {

    // MARK: - Properties

    private let viewModel: CourseRowViewModel
    let isHistory: Bool

    /// Set only for history rows, where it is the card's only action.
    let repeatAction: (() -> Void)?

    /// False while a copy is already running; the button stays visible but disabled.
    let canRepeat: Bool

    @State private var animatedProgress: Double = 0.0

    // MARK: - Init

    init(
        row: CourseRowViewModel,
        isHistory: Bool,
        canRepeat: Bool = true,
        repeatAction: (() -> Void)? = nil
    ) {
        self.viewModel = row
        self.isHistory = isHistory
        self.canRepeat = canRepeat
        self.repeatAction = repeatAction
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            info
            // Dim only the info: the Repeat button must not look disabled.
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

    // MARK: - Repeat button

    // LocalizedStringKey, not String: a String overload would skip localization.
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

    // MARK: - Subviews

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
                if !isHistory {
                    Text("Medications: \(viewModel.medicationsCount)")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                if isHistory {
                    Text("Course completed")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.accentPrimary)
                }
            }

            if isHistory, !viewModel.medications.isEmpty {
                medications
            }
        }
    }

    /// Prescribed medications, shown inline since history rows cannot be opened.
    private var medications: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
                .overlay(Color.textPrimary.opacity(0.08))

            ForEach(viewModel.medications) { medication in
                HStack(spacing: 10) {
                    Image(systemName: medication.systemImage)
                        .font(.caption)
                        .foregroundColor(.accentPrimary.opacity(0.8))
                        .frame(width: 18)

                    Text(medication.name)
                        .font(.subheadline)
                        .foregroundColor(.textPrimary.opacity(0.85))
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    // Same localization key as the course detail screen.
                    Text("\(medication.dosage) pcs")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.textSecondary)
                        .monospacedDigit()
                }
            }
        }
    }
}
