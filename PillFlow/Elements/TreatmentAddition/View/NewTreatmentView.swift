//
//  NewTreatmentView.swift
//  PillFlow
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI

struct NewTreatmentView<VM: NewTreatmentViewModelProtocol>: View {
    @StateObject private var viewModel: VM
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingAddMedication = false
    
    init(viewModel: @autoclosure @escaping () -> VM) {
        self._viewModel = StateObject(wrappedValue: viewModel())
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                Form {
                    Section(header: Text("Basic Information").foregroundColor(.textSecondary)) {
                        TextField("Course Name (e.g., Vitamins)", text: $viewModel.courseName)
                            .foregroundColor(.textPrimary)
                    }
                    .listRowBackground(Color.appSurface)
                    
                    Section(header: Text("Course Duration").foregroundColor(.textSecondary)) {
                        DatePicker("Start", selection: $viewModel.startDate, displayedComponents: .date)
                            .foregroundColor(.textPrimary)
                        // A course can't end before it starts: such a course saved
                        // silently and then produced no doses at all. CourseDetailView
                        // already had this constraint; here it was missing.
                        DatePicker("End", selection: $viewModel.endDate,
                                   in: viewModel.startDate..., displayedComponents: .date)
                            .foregroundColor(.textPrimary)
                    }
                    .listRowBackground(Color.appSurface)
                    
                    Section(header: Text("Medications").foregroundColor(.textSecondary)) {
                        ForEach(viewModel.medications) { med in
                            HStack {
                                Image(systemName: med.formSystemImage)
                                    .foregroundColor(.accentPrimary)
                                    .frame(width: 30)
                                Text(med.name).foregroundColor(.textPrimary)
                                Spacer()
                                // Two plurals in one string: Russian and Ukrainian
                                // decline them independently, so each gets its own
                                // translatable string.
                                (Text("\(med.dosage) pcs") + Text(verbatim: ", ") + Text("\(med.timesOfDay.count) times/day"))
                                    .font(.caption)
                                    .foregroundColor(.textSecondary)
                            }
                        }
                        .onDelete(perform: viewModel.deleteMedication)
                        
                        Button(action: {
                            showingAddMedication = true
                        }) {
                            Label("Add Medication", systemImage: "plus")
                                .foregroundColor(.accentPrimary)
                        }
                    }
                    .listRowBackground(Color.appSurface)
                    
                    Section {
                        Button(action: {
                            // Dismiss only if the write actually succeeded —
                            // otherwise what was typed would go with the screen.
                            if viewModel.saveCourse() { dismiss() }
                        }) {
                            Text("Save Course")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .foregroundColor(viewModel.isSaveEnabled ? Color.onAccent : .textPrimary.opacity(0.3))
                        }
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Dismiss only if the write actually succeeded — otherwise
                    // what was typed would go with the screen.
                    Button("Save") {
                        if viewModel.saveCourse() { dismiss() }
                    }
                    .font(.headline)
                    .foregroundColor(viewModel.isSaveEnabled ? .accentPrimary : .textTertiary)
                    .disabled(!viewModel.isSaveEnabled)
                }
                    }
                    .listRowBackground(viewModel.isSaveEnabled ? Color.accentPrimary : Color.textPrimary.opacity(0.1))
                    .disabled(!viewModel.isSaveEnabled)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.textPrimary.opacity(0.7))
                }
            }
            .appTheme()
            .sheet(isPresented: $showingAddMedication) {
                AddMedicationView { draft in
                    withAnimation { viewModel.addMedication(draft) }
                    showingAddMedication = false
                }
                .presentationDetents([.large])
            }
        }
    }
}

extension NewTreatmentView where VM == NewTreatmentViewModel {
    init() {
        self.init(viewModel: DIContainer.shared.resolve(NewTreatmentViewModel.self))
    }
}

#Preview {
    NewTreatmentView(viewModel: MockNewTreatmentViewModel())
        .environmentObject(AppRouter())
}
