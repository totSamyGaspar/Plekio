//
//  StatisticsView.swift
//  PillFlow
//
//  Created by Edward Gasparian on 06.05.2026.
//

import SwiftUI
import Combine

struct StatisticsView<VM: StatisticsViewModelProtocol>: View {
    @StateObject private var viewModel: VM
    
    // States for refill logic and notifications
    @State private var showingRefillAlert = false
    @State private var refillAmountText = ""
    @State private var selectedMedForRefill: MedicationItem?
    
    @State private var showSuccessToast = false
    @State private var successMessage = ""
    
    // Local colors
    let purpleAccent = Color(red: 0.7, green: 0.4, blue: 0.9)
    let warningBg = Color(red: 0.2, green: 0.05, blue: 0.08)
    let targetBlueBg = Color(red: 0.35, green: 0.4, blue: 0.95)
    
    init(viewModel: @autoclosure @escaping () -> VM) {
        self._viewModel = StateObject(wrappedValue: viewModel())
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgDark.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        
                        // SECTION 1: ADHERENCE & ALERTS
                        VStack(alignment: .leading, spacing: 16) {
                            Text("ADHERENCE & ALERTS")
                                .font(.caption.weight(.heavy))
                                .foregroundColor(purpleAccent)
                                .tracking(1.5)
                                .padding(.horizontal)
                            
                            // 1.1 Low Stock Cards
                            if viewModel.lowStockItems.isEmpty {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.neonMint)
                                    Text("All medications are well stocked")
                                        .foregroundColor(.white.opacity(0.7))
                                        .font(.subheadline)
                                }
                                .padding(.horizontal)
                            } else {
                                ForEach(viewModel.lowStockItems) { med in
                                    lowStockWarningCard(for: med)
                                }
                            }
                            
                            // 1.2 Daily Tip Card
                            dailyPracticeCard
                        }
                        .padding(.top, 20)
                        
                        // SECTION 2: ADHERENCE TARGET
                        adherenceTargetSection
                            .padding(.horizontal)
                        
                    }
                    .padding(.bottom, 110)
                }
                
                // MARK: - Toast (Success Notification)
                if showSuccessToast {
                    VStack {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.neonMint)
                            Text(successMessage)
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(Color.cardDark)
                        .cornerRadius(24)
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.neonMint.opacity(0.3), lineWidth: 1))
                        .shadow(color: Color.neonMint.opacity(0.2), radius: 10, x: 0, y: 5)
                        .padding(.top, 16)
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
                }
            }
            .alert("Refill Stock", isPresented: $showingRefillAlert, presenting: selectedMedForRefill) { med in
                TextField("Amount (e.g.: 30)", text: $refillAmountText)
                    .keyboardType(.numberPad)
                
                Button("Cancel", role: .cancel) { refillAmountText = "" }
                
                Button("Add") {
                    if let amount = Int(refillAmountText), amount > 0 {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            viewModel.refill(medication: med, amount: amount)
                        }
                        
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        successMessage = "\(med.name) stock increased by \(amount) units."
                        withAnimation(.spring()) { showSuccessToast = true }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation { showSuccessToast = false }
                        }
                    }
                }
            } message: { med in
                Text("How many units of \(med.name) would you like to add?")
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
    
    // MARK: - UI Components
    private func lowStockWarningCard(for med: MedicationItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                Text("LOW STOCK WARNING")
            }
            .font(.caption.weight(.heavy))
            .foregroundColor(Color(red: 0.9, green: 0.4, blue: 0.4))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(med.name) is running low")
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)
                Text("Remaining count: \(med.stockCount) pills")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Button(action: {
                selectedMedForRefill = med
                refillAmountText = ""
                showingRefillAlert = true
            }) {
                Text("REFILL STOCK")
                    .font(.subheadline.weight(.heavy))
                    .foregroundColor(Color.bgDark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.neonMint)
                    .cornerRadius(12)
            }
            .padding(.top, 4)
        }
        .padding(20)
        .background(warningBg)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(red: 0.9, green: 0.4, blue: 0.4).opacity(0.3), lineWidth: 1))
        .padding(.horizontal)
    }
    
    private var dailyPracticeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("DAILY PRACTICE CODE")
                .font(.caption.weight(.heavy))
                .foregroundColor(purpleAccent)
            Text("\"Taking Magnesium with a light snack can significantly improve absorption and reduce stomach upset.\"")
                .font(.body).italic().foregroundColor(.white.opacity(0.9)).lineSpacing(4)
            HStack {
                Spacer()
                Text("Tip rotates every 18s").font(.caption2).foregroundColor(purpleAccent.opacity(0.7))
            }
        }
        .padding(20)
        .background(Color.cardDark)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(purpleAccent.opacity(0.2), lineWidth: 1))
        .padding(.horizontal)
    }
    
    private var adherenceTargetSection: some View {
        VStack(spacing: 24) {
            Text("ADHERENCE TARGET")
                .font(.headline.weight(.heavy))
                .foregroundColor(.white)
                .tracking(1.5)
                .padding(.top, 24)
            
            CircularProgressView(
                progress: viewModel.progress > 0 ? viewModel.progress : 0,
                goal: 90
            )
            .frame(height: 220)
            
            HStack(spacing: 6) {
                Text("🔥")
                Text("\(viewModel.streakDays) days streak!")
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.15))
            .cornerRadius(20)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity)
        .background(targetBlueBg)
        .cornerRadius(40)
    }
}

// MARK: - DI Extension & Preview
extension StatisticsView where VM == StatisticsViewModel {
    init() {
        self.init(viewModel: DIContainer.shared.resolve((any StatisticsViewModelProtocol).self) as! VM)
    }
}

final class MockStatisticsViewModel: StatisticsViewModelProtocol {
    @Published var takenCount: Int = 13
    @Published var totalCount: Int = 14
    var progress: Double { return 0.93 }
    @Published var streakDays: Int = 1
    @Published var lowStockItems: [MedicationItem] = []
    
    init() {}
    func loadStats() {}
    func refill(medication: MedicationItem, amount: Int) {}
}

#Preview {
    StatisticsView(viewModel: MockStatisticsViewModel())
        .preferredColorScheme(.dark)
}
