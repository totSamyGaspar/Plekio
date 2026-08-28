//
//  AddMedicationView.swift
//  PillFlow
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI

struct AddMedicationView<VM: AddMedicationViewModelProtocol>: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var viewModel: VM

    /// The medication being edited (nil means adding a new one). Consumed in
    /// `.task` rather than `init`: SwiftUI re-creates the view struct many times.
    private let medicationToEdit: MedicationItem?
    private var isEditing: Bool { medicationToEdit != nil }

    var onSave: (MedicationDraft) -> Void

    init(viewModel: @autoclosure @escaping () -> VM,
         editingMedication: MedicationItem? = nil,
         onSave: @escaping (MedicationDraft) -> Void) {
        self._viewModel = StateObject(wrappedValue: viewModel())
        self.medicationToEdit = editingMedication
        self.onSave = onSave
    }

    let forms = [
        ("pills.fill", "Pill"),
        ("capsule.fill", "Capsule"),
        ("drop.fill", "Drops"),
        ("syringe.fill", "Injection")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgDark.ignoresSafeArea()

                Form {
                    // MARK: - Photo Section
                    Section(
                        header: Text("Image")
                            .foregroundColor(.white.opacity(0.6))
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
                                            .foregroundColor(.neonMint)
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

                    // MARK: - Basic Details
                    Section(header: Text("Medication").foregroundColor(.white.opacity(0.6))) {
                        TextField("Name (e.g., Ibuprofen)", text: $viewModel.draft.name)
                            .foregroundColor(.white)

                        Picker("Form", selection: $viewModel.draft.formSystemImage) {
                            ForEach(forms, id: \.0) { form in
                                Image(systemName: form.0)
                                    .tag(form.0)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(Color.cardDark)

                    // MARK: - Inventory Tracking
                    Section(header: Text("Inventory Tracking").foregroundColor(.white.opacity(0.6))) {
                        HStack {
                            Text("Total in package (pcs)")
                                .foregroundColor(.white)
                            Spacer()
                            // These fields accepted any number, negatives included.
                            TextField("30", value: Binding(
                                get: { viewModel.draft.stockCount },
                                set: { viewModel.draft.stockCount = min(max($0, 0), 9999) }
                            ), format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(.neonMint)
                                .font(.headline)
                                .padding(.trailing)
                        }

                        HStack {
                            Text("Remind when remaining")
                                .foregroundColor(.white)
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
                    .listRowBackground(Color.cardDark)

                    // MARK: - Frequency and Dosage
                    Section(header: Text("Intake Frequency").foregroundColor(.white.opacity(0.6))) {
                        Picker("Interval", selection: $viewModel.draft.frequencyDays) {
                            ForEach(DoseFrequency.allCases) { frequency in
                                Text(frequency.title).tag(frequency.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .accentColor(.neonMint)
                        .foregroundColor(.white)
                    }
                    .listRowBackground(Color.cardDark)

                    Section(header: Text("Dosage").foregroundColor(.white.opacity(0.6))) {
                        Stepper("Quantity: \(viewModel.draft.dosage)", value: $viewModel.draft.dosage, in: 1...10)
                            .foregroundColor(.white)
                    }
                    .listRowBackground(Color.cardDark)

                    // MARK: - Intake Time
                    Section(header: Text("Intake Time").foregroundColor(.white.opacity(0.6))) {
                        // ForEach over 0..<count needs a CONSTANT range, but this
                        // array changes on screen: adding or removing a time caused
                        // glitches and access by a stale index. Iterate the
                        // collection instead and bounds-check each element access.
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
                            .foregroundColor(.white)
                        }
                        .onDelete { offsets in
                            // A medication with no intake times lands in neither the
                            // schedule nor the notifications — keep at least one slot.
                            guard viewModel.draft.timesOfDay.count > offsets.count else { return }
                            viewModel.draft.timesOfDay.remove(atOffsets: offsets)
                        }

                        Button(action: {
                            let lastTime = viewModel.draft.timesOfDay.last ?? Date()
                            let newTime = Calendar.current.date(byAdding: .hour, value: 4, to: lastTime) ?? Date()
                            viewModel.draft.timesOfDay.append(newTime)
                        }) {
                            Label("Add time", systemImage: "plus.circle.fill")
                                .foregroundColor(.neonMint)
                        }
                    }
                    .listRowBackground(Color.cardDark)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(isEditing ? "Edit Medication" : "New Medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white.opacity(0.7))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Save" : "Add") {
                        onSave(viewModel.draft)
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(viewModel.draft.name.isEmpty ? .white.opacity(0.3) : .neonMint)
                    .disabled(viewModel.draft.name.isEmpty)
                }
            }
            .confirmationDialog("Choose Photo", isPresented: $viewModel.showingPhotoSourceMenu, titleVisibility: .visible) {
                Button("Take Photo (Camera)") {
                    viewModel.requestImageSelection(source: .camera)
                }
                Button("Choose from Library") {
                    viewModel.requestImageSelection(source: .photoLibrary)
                }
                Button("Cancel", role: .cancel) { }
            }
            .task {
                guard let medicationToEdit else { return }
                await viewModel.startEditing(medicationToEdit)
            }
        }
    }
}

struct ImagePreviewView: View {
    var image: UIImage?

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.cardDark)
                .frame(width: 100, height: 100)
                .overlay(
                    Circle()
                        .stroke(Color.neonMint.opacity(0.5), lineWidth: 2)
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
                .foregroundColor(.white.opacity(0.5))
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Extensions for Init
extension AddMedicationView where VM == AddMedicationViewModel {

    init(onSave: @escaping (MedicationDraft) -> Void) {
        self.init(
            viewModel: DIContainer.shared.resolve(AddMedicationViewModel.self),
            onSave: onSave
        )
    }

    /// Opens the form on an existing medication. Filling the draft and loading the
    /// photo is done by `startEditing(_:)` from `.task`.
    init(editingMedication: MedicationItem, onSave: @escaping (MedicationDraft) -> Void) {
        self.init(
            viewModel: DIContainer.shared.resolve(AddMedicationViewModel.self),
            editingMedication: editingMedication,
            onSave: onSave
        )
    }
}

#Preview {
    AddMedicationView(onSave: { _ in })
        .preferredColorScheme(.dark)
}
