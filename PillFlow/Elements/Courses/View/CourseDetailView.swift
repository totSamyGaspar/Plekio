//
//  CourseDetailView.swift
//  PillFlow
//
//  Created by Edward Gasparian on 03.05.2026.
//

import SwiftUI

struct CourseDetailView<VM: CourseDetailViewModelProtocol>: View {
    @StateObject private var viewModel: VM
    @EnvironmentObject private var router: AppRouter
    
    @State private var showingAddMedication = false
    @State private var medicationToEdit: MedicationItem?
    
    init(viewModel: @autoclosure @escaping () -> VM) {
        self._viewModel = StateObject(wrappedValue: viewModel())
    }
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            Form {
                Section(header: Text("Course Settings").foregroundColor(.textSecondary)) {
                    TextField("Course Name", text: $viewModel.courseName)
                        .foregroundColor(.textPrimary)
                        .onSubmit { viewModel.saveCourseChanges() }
                    DatePicker("Start", selection: $viewModel.startDate, displayedComponents: .date)
                        .foregroundColor(.textPrimary)
                    DatePicker("End", selection: $viewModel.endDate,
                               in: viewModel.startDate..., displayedComponents: .date)
                    .foregroundColor(.textPrimary)
                }
                .listRowBackground(Color.appSurface)
                
                Section(header: Text("Medications in Course").foregroundColor(.textSecondary)) {
                    if viewModel.medications.isEmpty {
                        Text("No medications in this course")
                            .foregroundColor(.textSecondary)
                    } else {
                        ForEach(viewModel.medications) { med in
                            HStack(spacing: 12) {
                                MedicationRowView(med: med)
                                Button(action: {
                                    medicationToEdit = med
                                }) {
                                    Image(systemName: "pencil")
                                        .font(.title2)
                                        .foregroundColor(.textTertiary)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        .onDelete(perform: viewModel.deleteMedication)
                    }
                }
                .listRowBackground(Color.appSurface)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Course Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingAddMedication = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentPrimary)
                }
            }
        }
        .sheet(isPresented: $showingAddMedication) {
            AddMedicationView { draft in
                viewModel.addNewMedication(draft)
                showingAddMedication = false
            }
        }
        .sheet(item: $medicationToEdit) { med in
            AddMedicationView(editingMedication: med) { updatedDraft in
                viewModel.updateMedication(medication: med, with: updatedDraft)
                medicationToEdit = nil
            }
        }
        .onChange(of: viewModel.startDate) { _, _ in viewModel.saveCourseChanges() }
        .onChange(of: viewModel.endDate)   { _, _ in viewModel.saveCourseChanges() }
        .onDisappear { viewModel.saveCourseChanges() }
    }
}

extension CourseDetailView where VM == CourseDetailViewModel {
    init(course: TreatmentCourse) {
        self.init(viewModel: DIContainer.shared.resolve(CourseDetailViewModel.self, argument: course))
    }
}

struct CourseDetailDestination: View {
    let courseId: UUID

    var body: some View {
        if let course = DIContainer.shared.resolve(DatabaseServiceProtocol.self).fetchCourse(id: courseId) {
            CourseDetailView(course: course)
        } else {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ContentUnavailableView(
                    "Course deleted",
                    systemImage: "trash",
                    description: Text("This course no longer exists.")
                )
            }
            .navigationTitle("Course Details")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

