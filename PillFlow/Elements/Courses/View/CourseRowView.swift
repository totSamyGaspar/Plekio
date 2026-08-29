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
    
    @State private var animatedProgress: Double = 0.0
    
    init(course: TreatmentCourse, isHistory: Bool) {
        self.viewModel = CourseRowViewModel(course: course)
        self.isHistory = isHistory
    }
    
    var body: some View {
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
        .padding(20)
        .background(Color.appSurface)
        .cornerRadius(24)
        .opacity(isHistory ? 0.7 : 1.0)
        .onAppear {
            animatedProgress = viewModel.daysProgress
        }
    }
}
