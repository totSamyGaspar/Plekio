//
//  PeriodSectionView.swift
//  PillFlow
//
//  Created by Edward Gasparian on 20.05.2026.
//

import SwiftUI

struct PeriodSectionView: View {
    let title: LocalizedStringResource
    let pills: [PillDose]
    let onTogglePill: (PillDose.ID) -> Void
    let onPillTap: (PillDose) -> Void
    /// Every dose in the section that is still open. The group sheet lives here
    /// rather than on a tap of any single card: on the card it puts the whole-slot
    /// action on the big target and the one-dose action on a 28pt circle, which is
    /// the wrong way round for the thing people do most.
    let onTakeAll: ([PillDose]) -> Void
    
    private var pendingPills: [PillDose] { pills.filter { !$0.isTaken && !$0.isSkipped } }
    
    private var timeString: String {
        guard let first = pills.first?.time else { return "" }
        let firstText = first.formatted(date: .omitted, time: .shortened)
        
        guard let last = pills.last?.time, last != first else { return firstText }
        return "\(firstText) – \(last.formatted(date: .omitted, time: .shortened))"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle().fill(Color.accentPrimary).frame(width: 10, height: 10)
                    .shadow(color: .accentPrimary.opacity(0.5), radius: 4)
                Text(title).font(.headline).foregroundColor(.textPrimary).lineLimit(1)
                Spacer()
                Text(timeString).font(.subheadline).foregroundColor(.textSecondary)
                
                if !pendingPills.isEmpty {
                    Button { onTakeAll(pendingPills) } label: {
                        Text("Take All")
                            .font(.caption.weight(.heavy))
                            .foregroundColor(.accentPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.accentPrimary.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .expandTouchTarget(vertical: 8, horizontal: 4)
                }
            }
            
            ForEach(pills) { pill in
                MedicationCardView(
                    pill: pill,
                    onToggle: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            onTogglePill(pill.id)
                            hapticFeedback()
                        }
                    },
                    onTapCard: {
                        onPillTap(pill)
                    }
                )
            }
        }
        .padding(.horizontal)
    }
    
    private func hapticFeedback() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
}
