//
//  DashboardEmptyDay.swift
//  Plekio
//
//  Created by Edward Gasparian on 11.11.2026.
//

import SwiftUI

/// A day without doses. Before the first course it offers to create one.
struct DashboardEmptyDay: View {
    let hasCourses: Bool
    let onCreateCourse: () -> Void

    var body: some View {
        if hasCourses {
            EmptyStateView(icon: "pills", title: "Nothing for today", verticalPadding: 60)
        } else {
            EmptyStateView(
                icon: "pills",
                title: "Add your first course to see your doses here",
                verticalPadding: 60,
                actionTitle: "Create a course",
                action: onCreateCourse
            )
        }
    }
}
