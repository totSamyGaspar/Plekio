//
//  AddMedicationView.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI

struct AddMedicationView<VM: AddMedicationViewModelProtocol>: View {

    // MARK: - Properties

    @Environment(\.dismiss) private var dismiss

    @StateModel private var viewModel: VM

    /// Nil when adding. Consumed in `.task`, not `init`, which SwiftUI re-runs often.
    private let medicationToEdit: MedicationSnapshot?
    private var isEditing: Bool { medicationToEdit != nil }

    var onSave: (MedicationDraft) -> Void

    // MARK: - Init

    init(viewModel: @autoclosure @escaping () -> VM,
         editingMedication: MedicationSnapshot? = nil,
         onSave: @escaping (MedicationDraft) -> Void) {
        self._viewModel = StateModel(wrappedValue: viewModel())
        self.medicationToEdit = editingMedication
        self.onSave = onSave
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                Section(header: header("Image")) {
                    MedicationPhotoPicker(
                        image: viewModel.selectedImage,
                        onChoose: { viewModel.showingPhotoSourceMenu = true },
                        onRemove: { viewModel.removeImage() }
                    )
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Group {
                    Section(header: header("Medication")) {
                        TextField("Name (e.g., Ibuprofen)", text: $viewModel.draft.name)
                            .foregroundStyle(Color.textPrimary)
                            .accessibilityIdentifier(AccessibilityID.NewMedication.name)

                        Picker("Form", selection: $viewModel.draft.form) {
                            ForEach(MedicationForm.allCases, id: \.self) { form in
                                Image(systemName: form.systemImage).tag(form)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.vertical, 8)
                    }

                    Section(header: header("Inventory Tracking")) {
                        CountRow(title: "Total in package (pcs)", placeholder: "30",
                                 value: $viewModel.draft.stockCount, tint: .accentPrimary,
                                 identifier: AccessibilityID.NewMedication.stock)

                        CountRow(title: "Remind when remaining", placeholder: "10",
                                 value: $viewModel.draft.lowStockThreshold, tint: .warningAmber,
                                 identifier: AccessibilityID.NewMedication.lowStockThreshold)

                        if viewModel.draft.isLowFromTheStart {
                            Text("That's the whole package or more, so it will count as running low right away.")
                                .font(.footnote)
                                .foregroundStyle(Color.textSecondary)
                                .accessibilityIdentifier(AccessibilityID.NewMedication.lowFromTheStartHint)
                        }
                    }

                    Section(header: header("Intake Frequency")) {
                        Picker("Interval", selection: $viewModel.draft.frequencyDays) {
                            ForEach(DoseFrequency.allCases) { frequency in
                                Text(frequency.title).tag(frequency.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.accentPrimary)
                        .foregroundStyle(Color.textPrimary)
                    }

                    Section(header: header("Dosage")) {
                        Stepper("Quantity: \(viewModel.draft.dosage)", value: $viewModel.draft.dosage, in: 1...10)
                            .foregroundStyle(Color.textPrimary)
                    }

                    Section(header: header("Intake Time")) {
                        TimeOfDayRows(minutes: $viewModel.draft.minutesOfDay) { index in
                            Text("Dose \(index + 1)")
                        }
                    }

                    Section(header: header("Meals")) {
                        MealTimingPicker(selection: $viewModel.draft.mealTiming)
                    }
                }
                .listRowBackground(Color.appSurface)
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle(isEditing ? "Edit Medication" : "New Medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .photoSourceDialog("Choose Photo", isPresented: $viewModel.showingPhotoSourceMenu) { image in
                Task { await viewModel.attachPhoto(image) }
            }
            .task {
                guard let medicationToEdit else { return }
                await viewModel.startEditing(medicationToEdit)
            }
        }
    }

    // MARK: - Parts

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") { dismiss() }
                .foregroundStyle(Color.textPrimary.opacity(0.7))
                .accessibilityIdentifier(AccessibilityID.NewMedication.cancel)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(isEditing ? "Save" : "Add") {
                onSave(viewModel.draft.forSaving)
                dismiss()
            }
            .font(.headline)
            .foregroundStyle(viewModel.draft.isValid ? Color.accentPrimary : .textTertiary)
            .disabled(!viewModel.draft.isValid)
            .accessibilityIdentifier(AccessibilityID.NewMedication.save)
        }
    }

    /// `LocalizedStringResource`, so the literals passed in still reach the string catalog.
    private func header(_ title: LocalizedStringResource) -> some View {
        Text(title).foregroundStyle(Color.textSecondary)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    AddMedicationView(viewModel: AppDependencies.preview.makeAddMedicationViewModel(), onSave: { _ in })
        .appTheme()
}
#endif
