//
//  StatisticsView.swift
//  Plekio
//
//  Created by Edward Gasparian on 06.05.2026.
//

import SwiftUI
import Combine

struct StatisticsView<VM: StatisticsViewModelProtocol>: View {

    // MARK: - Properties

    @Environment(AppDependencies.self) private var dependencies
    @StateObject private var viewModel: VM

    @State private var showingRefillAlert = false
    @State private var refillAmountText = ""
    @State private var selectedMedForRefill: MedicationSnapshot?

    // MARK: - Init

    init(viewModel: @autoclosure @escaping () -> VM) {
        self._viewModel = StateObject(wrappedValue: viewModel())
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 22) {
            VStack(alignment: .leading, spacing: 16) {
                // One line in every language; longer translations shrink instead of wrapping.
                Text("Adherence & Alerts")
                    .scaledFont(size: 24, relativeTo: .title2, weight: .heavy, design: .serif)
                    .foregroundColor(.textPrimary)
                    .tracking(1.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal)

                if viewModel.lowStockItems.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.accentPrimary)
                        Text("All medications are well stocked")
                            .foregroundColor(.textPrimary.opacity(0.7))
                            .font(.subheadline)
                    }
                    .padding(.horizontal)
                } else {
                    ForEach(viewModel.lowStockItems) { med in
                        lowStockWarningCard(for: med)
                    }
                }
            }
            .padding(.top, 20)

            adherenceTargetSection
                .padding(.horizontal)

        }
        .alert("Refill Stock", isPresented: $showingRefillAlert, presenting: selectedMedForRefill) { med in
            TextField("Amount (e.g.: 30)", text: $refillAmountText)
                .keyboardType(.numberPad)

            Button("Cancel", role: .cancel) { refillAmountText = "" }

            Button("Add") {
                if let amount = Int(refillAmountText), amount > 0 {
                    let saved = withMotion(Motion.standard) {
                        viewModel.refill(medication: med, amount: amount)
                    }
                    // A failed save shows the error alert; no success toast on top.
                    guard saved else { return }

                    dependencies.toasts.show(.success("\(med.name) stock increased by \(amount) units."))
                }
            }
        } message: { med in
            Text("How many units of \(med.name) would you like to add?")
        }
    }

    // MARK: - Subviews

    private func lowStockWarningCard(for med: MedicationSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                Text("LOW STOCK WARNING")
            }
            .font(.caption.weight(.heavy))
            .foregroundColor(.warningAccent)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(med.name) is running low")
                    .font(.headline.weight(.bold))
                    .foregroundColor(.textPrimary)
                Text("Remaining count: \(med.stockCount) pills")
                    .font(.subheadline)
                    .foregroundColor(.textPrimary.opacity(0.7))
            }

            Button(action: {
                selectedMedForRefill = med
                refillAmountText = ""
                showingRefillAlert = true
            }) {
                Text("REFILL STOCK")
                    .font(.subheadline.weight(.heavy))
                    .foregroundColor(Color.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentPrimary)
                    .cornerRadius(12)
            }
            .padding(.top, 4)
        }
        .padding(20)
        .background(Color.warningBg)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.warningAccent.opacity(0.3), lineWidth: 1))
        .padding(.horizontal)
    }

    private var adherenceTargetSection: some View {
        VStack {
            Text("ADHERENCE TARGET")
                .font(.headline.weight(.heavy))
                .foregroundColor(.accentPrimary)
                .tracking(1.5)
                .padding(.top, 24)

            HStack(alignment: .center, spacing: 16) {
                CircularProgressView(progress: viewModel.progress)
                    .frame(height: 100)

                VStack(spacing: 10) {
                    Text(verbatim: "🔥")
                        .font(.headline.weight(.bold))
                    Text("\(viewModel.streakDays) days streak!")
                        .font(.headline.weight(.bold))
                        .foregroundColor(.textPrimary)
                        .multilineTextAlignment(.center)
                        .animatedNumber(Double(viewModel.streakDays))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.textPrimary.opacity(0.15))
                .cornerRadius(20)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.appSurface)
        .cornerRadius(20)
    }
}

// MARK: - Mock

#if DEBUG
final class MockStatisticsViewModel: StatisticsViewModelProtocol {
    var progress: Double { 0.93 }
    @Published var streakDays: Int = 1
    @Published var lowStockItems: [MedicationSnapshot] = []

    init() {}
    func loadStats() {}
    func refill(medication: MedicationSnapshot, amount: Int) -> Bool { true }
}
#endif

// MARK: - Preview

#Preview {
    StatisticsView(viewModel: MockStatisticsViewModel())
        .environment(AppDependencies.preview)
        .appTheme()
}
