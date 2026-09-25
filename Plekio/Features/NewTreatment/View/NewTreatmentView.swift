//
//  NewTreatmentView.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI

struct NewTreatmentView<VM: NewTreatmentViewModelProtocol>: View {

    // MARK: - Properties

    @Environment(AppDependencies.self) private var dependencies
    @StateObject private var viewModel: VM
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss

    @State private var showingAddMedication = false

    // MARK: - Init

    init(viewModel: @autoclosure @escaping () -> VM) {
        self._viewModel = StateObject(wrappedValue: viewModel())
    }

    // MARK: - Body

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
                        // An end before the start would yield a course with no doses.
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
                                // Separate strings: each plural is declined independently in ru/uk.
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Dismiss only on success so typed input isn't lost.
                    Button("Save") {
                        guard viewModel.saveCourse() else { return }
                        dependencies.toasts.show(.success("Course created"))
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(viewModel.isSaveEnabled ? .accentPrimary : .textTertiary)
                    .disabled(!viewModel.isSaveEnabled)
                }
            }
            .appTheme()
            .sheet(isPresented: $showingAddMedication) {
                AddMedicationView(viewModel: dependencies.makeAddMedicationViewModel()) { draft in
                    withAnimation { viewModel.addMedication(draft) }
                    showingAddMedication = false
                }
                .presentationDetents([.large])
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NewTreatmentView(viewModel: MockNewTreatmentViewModel())
        .environmentObject(AppRouter())
        .environment(AppDependencies.preview)
}
