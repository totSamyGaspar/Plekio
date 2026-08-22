//
//  MedicationRowView.swift
//  PillFlow
//
//  Created by Edward Gasparian on 03.05.2026.
//

import SwiftUI
import Combine

struct MedicationRowView: View {
    let med: MedicationItem
    
    @State private var uiImage: UIImage? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            
            // MARK: - Medication Icon or Photo (UX Improvement)
            
            Group {
                if let uiImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 0.5)
                        )
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.mint.opacity(0.12))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: med.formSystemImage)
                            .font(.system(size: 20))
                            .foregroundColor(.mint)
                    }
                }
            }
            
            // MARK: - Information Block
            
            VStack(alignment: .leading, spacing: 4) {
                Text(med.name)
                    .font(.headline)
                
                Text(frequencyString(for: med.frequencyDays))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(med.dosage) pcs")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .onAppear {
            loadAsyncImage()
        }
        // med.id stays the same after editing (same SwiftData object), so SwiftUI
        // doesn't recreate this row and onAppear won't fire again. Listen for
        // .databaseDidUpdate (posted by DatabaseService.updateMedication) to force
        // a reload of the photo instead.
        .onReceive(NotificationCenter.default.publisher(for: .databaseDidUpdate)) { _ in
            loadAsyncImage(force: true)
        }
    }

    private func loadAsyncImage(force: Bool = false) {
        // force: true forces a reload (used after .databaseDidUpdate), ignoring
        // any previously loaded image.
        guard force || uiImage == nil else { return }
        ImageCache.shared.loadAsync(for: med.id) { image in
            self.uiImage = image
        }
    }
    
    private func frequencyString(for days: Int) -> String {
        switch days {
        case 1: return "Every day"
        case 2: return "Every other day"
        case 3: return "Every 3 days"
        case 7: return "Once a week"
        case 14: return "Every 2 weeks"
        case 30: return "Once a month"
        default: return "Every \(days) days"
        }
    }
}
