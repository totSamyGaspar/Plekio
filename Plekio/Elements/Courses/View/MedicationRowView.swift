//
//  MedicationRowView.swift
//  Plekio
//
//  Created by Edward Gasparian on 03.05.2026.
//

import SwiftUI
import Combine

struct MedicationRowView: View {
    let med: MedicationSnapshot
    
    var body: some View {
        HStack(spacing: 12) {
            
            // MARK: - Medication Icon or Photo
            
            MedicationPhotoView(medicationId: med.id, size: 40, cornerRadius: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentPrimary.opacity(0.12))
                    Image(systemName: med.formSystemImage)
                        .scaledFont(size: 20, relativeTo: .title3)
                        .foregroundColor(.accentPrimary)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.textPrimary.opacity(0.12), lineWidth: 0.5)
            )
            
            // MARK: - Information Block
            
            VStack(alignment: .leading, spacing: 4) {
                Text(med.name)
                    .font(.headline)
                
                Text(DoseFrequency.title(forDays: med.frequencyDays))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(med.dosage) pcs")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
