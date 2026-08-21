//
//  NewTreatmentView.swift
//  PillFlow
//
//  Created by Edward Gasparian on 02.05.2026.
//

// NewTreatmentView.swift
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
                Color.bgDark.ignoresSafeArea()
                
                Form {
                    Section(header: Text("Basic Information").foregroundColor(.white.opacity(0.6))) {
                        TextField("Course Name (e.g., Vitamins)", text: $viewModel.courseName)
                            .foregroundColor(.white)
                    }
                    .listRowBackground(Color.cardDark)
                    
                    Section(header: Text("Course Duration").foregroundColor(.white.opacity(0.6))) {
                        DatePicker("Start", selection: $viewModel.startDate, displayedComponents: .date)
                            .foregroundColor(.white)
                        DatePicker("End", selection: $viewModel.endDate, displayedComponents: .date)
                            .foregroundColor(.white)
                    }
                    .listRowBackground(Color.cardDark)
                    
                    Section(header: Text("Medications").foregroundColor(.white.opacity(0.6))) {
                        ForEach(viewModel.medications) { med in
                            HStack {
                                Image(systemName: med.formSystemImage)
                                    .foregroundColor(.neonMint)
                                    .frame(width: 30)
                                Text(med.name).foregroundColor(.white)
                                Spacer()
                                Text("\(med.dosage) pcs, \(med.timesOfDay.count) times/day")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .onDelete(perform: viewModel.deleteMedication)
                        
                        Button(action: {
                            showingAddMedication = true
                        }) {
                            Label("Add Medication", systemImage: "plus")
                                .foregroundColor(.neonMint)
                        }
                    }
                    .listRowBackground(Color.cardDark)
                    
                    Section {
                        Button(action: {
                            viewModel.saveCourse()
                            dismiss()
                        }) {
                            Text("Save Course")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .foregroundColor(viewModel.isSaveEnabled ? Color.bgDark : .white.opacity(0.3))
                        }
                    }
                    .listRowBackground(viewModel.isSaveEnabled ? Color.neonMint : Color.white.opacity(0.1))
                    .disabled(!viewModel.isSaveEnabled)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.bgDark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .preferredColorScheme(.dark)
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
        self.init(viewModel: DIContainer.shared.resolve((any NewTreatmentViewModelProtocol).self) as! VM)
    }
}

#Preview {
    NewTreatmentView(viewModel: MockNewTreatmentViewModel())
        .environmentObject(AppRouter())
}
