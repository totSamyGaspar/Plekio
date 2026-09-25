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

    @StateObject private var viewModel: VM

    /// Nil when adding. Consumed in `.task`, not `init`, which SwiftUI re-runs often.
    private let medicationToEdit: MedicationSnapshot?
    private var isEditing: Bool { medicationToEdit != nil }

    var onSave: (MedicationDraft) -> Void

    // MARK: - Init

    init(viewModel: @autoclosure @escaping () -> VM,
         editingMedication: MedicationSnapshot? = nil,
         onSave: @escaping (MedicationDraft) -> Void) {
        self._viewModel = StateObject(wrappedValue: viewModel())
        self.medicationToEdit = editingMedication
        self.onSave = onSave
    }

    // MARK: - Constants

    let forms = [
        ("pills.fill", "Pill"),
        ("capsule.fill", "Capsule"),
        ("drop.fill", "Drops"),
        ("syringe.fill", "Injection")
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                Form {
                    Section(
                        header: Text("Image")
                            .foregroundColor(.textSecondary)
                    ) {
                        HStack {
                            Spacer()
                            VStack(spacing: 12) {
                                Button {
                                    viewModel.showingPhotoSourceMenu = true
                                } label: {
                                    ImagePreviewView(image: viewModel.selectedImage)
                                }

                                HStack(spacing: 20) {
                                    Button {
                                        viewModel.showingPhotoSourceMenu = true
                                    } label: {
                                        Text(viewModel.selectedImage == nil ? "Add" : "Change")
                                            .foregroundColor(.accentPrimary)
                                    }

                                    if viewModel.selectedImage != nil {
                                        Button(role: .destructive) {
                                            withAnimation {
                                                viewModel.removeImage()
                                            }
                                        } label: {
                                            Text("Delete")
                                        }
                                    }
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }

                    Section(header: Text("Medication").foregroundColor(.textSecondary)) {
                        TextField("Name (e.g., Ibuprofen)", text: $viewModel.draft.name)
                            .foregroundColor(.textPrimary)

                        Picker("Form", selection: $viewModel.draft.formSystemImage) {
                            ForEach(forms, id: \.0) { form in
                                Image(systemName: form.0)
                                    .tag(form.0)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(Color.appSurface)

                    Section(header: Text("Inventory Tracking").foregroundColor(.textSecondary)) {
                        HStack {
                            Text("Total in package (pcs)")
                                .foregroundColor(.textPrimary)
                            Spacer()
                            TextField("30", value: Binding(
                                get: { viewModel.draft.stockCount },
                                set: { viewModel.draft.stockCount = min(max($0, 0), 9999) }
                            ), format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.accentPrimary)
                            .font(.headline)
                            .padding(.trailing)
                        }

                        HStack {
                            Text("Remind when remaining")
                                .foregroundColor(.textPrimary)
                            Spacer()
                            TextField("10", value: Binding(
                                get: { viewModel.draft.lowStockThreshold },
                                set: { viewModel.draft.lowStockThreshold = min(max($0, 0), 9999) }
                            ), format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.yellow)
                            .font(.headline)
                            .padding(.trailing)
                        }
                    }
                    .listRowBackground(Color.appSurface)

                    Section(header: Text("Intake Frequency").foregroundColor(.textSecondary)) {
                        Picker("Interval", selection: $viewModel.draft.frequencyDays) {
                            ForEach(DoseFrequency.allCases) { frequency in
                                Text(frequency.title).tag(frequency.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .accentColor(.accentPrimary)
                        .foregroundColor(.textPrimary)
                    }
                    .listRowBackground(Color.appSurface)

                    Section(header: Text("Dosage").foregroundColor(.textSecondary)) {
                        Stepper("Quantity: \(viewModel.draft.dosage)", value: $viewModel.draft.dosage, in: 1...10)
                            .foregroundColor(.textPrimary)
                    }
                    .listRowBackground(Color.appSurface)

                    Section(header: Text("Intake Time").foregroundColor(.textSecondary)) {
                        // The array changes on screen, so iterate it (not 0..<count)
                        // and bounds-check each access against stale indices.
                        ForEach(Array(viewModel.draft.timesOfDay.enumerated()), id: \.offset) { index, _ in
                            DatePicker("Dose \(index + 1)", selection: Binding(
                                get: {
                                    viewModel.draft.timesOfDay.indices.contains(index)
                                    ? viewModel.draft.timesOfDay[index]
                                    : Date()
                                },
                                set: {
                                    guard viewModel.draft.timesOfDay.indices.contains(index) else { return }
                                    viewModel.draft.timesOfDay[index] = $0
                                }
                            ), displayedComponents: .hourAndMinute)
                            .foregroundColor(.textPrimary)
                        }
                        .onDelete { offsets in
                            // Keep at least one time, or the medication is never scheduled.
                            guard viewModel.draft.timesOfDay.count > offsets.count else { return }
                            viewModel.draft.timesOfDay.remove(atOffsets: offsets)
                        }

                        Button(action: {
                            let lastTime = viewModel.draft.timesOfDay.last ?? Date()
                            let newTime = Calendar.current.date(byAdding: .hour, value: 4, to: lastTime) ?? Date()
                            viewModel.draft.timesOfDay.append(newTime)
                        }) {
                            Label("Add time", systemImage: "plus.circle.fill")
                                .foregroundColor(.accentPrimary)
                        }
                    }
                    .listRowBackground(Color.appSurface)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(isEditing ? "Edit Medication" : "New Medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.textPrimary.opacity(0.7))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Save" : "Add") {
                        onSave(viewModel.draft)
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(viewModel.draft.name.isEmpty ? .textTertiary : .accentPrimary)
                    .disabled(viewModel.draft.name.isEmpty)
                }
            }
            .photoSourceDialog("Choose Photo", isPresented: $viewModel.showingPhotoSourceMenu) { image in
                Task { await viewModel.attachPhoto(image) }
            }
            .task {
                guard let medicationToEdit else { return }
                await viewModel.startEditing(medicationToEdit)
            }
        }
    }
}

// MARK: - ImagePreviewView

struct ImagePreviewView: View {
    var image: UIImage?

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.appSurface)
                .frame(width: 100, height: 100)
                .overlay(
                    Circle()
                        .stroke(Color.accentPrimary.opacity(0.5), lineWidth: 2)
                )

            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "camera.fill")
                        .font(.largeTitle)
                    Text("Photo")
                        .font(.caption2)
                }
                .foregroundColor(.textSecondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    AddMedicationView(viewModel: AppDependencies.preview.makeAddMedicationViewModel(), onSave: { _ in })
        .appTheme()
}
