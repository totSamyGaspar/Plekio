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

    // Whether we're editing an existing medication (vs adding a new one)
    private let isEditing: Bool
    var onSave: (MedicationDraft) -> Void

    init(viewModel: @autoclosure @escaping () -> VM, isEditing: Bool = false, onSave: @escaping (MedicationDraft) -> Void) {
        self._viewModel = StateObject(wrappedValue: viewModel())
        self.isEditing = isEditing
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
                            TextField("30", value: $viewModel.draft.stockCount, format: .number)
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
                            TextField("10", value: $viewModel.draft.lowStockThreshold, format: .number)
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
                            Text("Every day").tag(1)
                            Text("Every other day").tag(2)
                            Text("Every 3 days").tag(3)
                            Text("Once a week").tag(7)
                            Text("Every 2 weeks").tag(14)
                            Text("Once a month").tag(30)
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
                        ForEach(0..<viewModel.draft.timesOfDay.count, id: \.self) { index in
                            DatePicker("Dose \(index + 1)", selection: Binding(
                                get: { viewModel.draft.timesOfDay[index] },
                                set: { viewModel.draft.timesOfDay[index] = $0 }
                            ), displayedComponents: .hourAndMinute)
                            .foregroundColor(.white)
                        }
                        .onDelete { viewModel.draft.timesOfDay.remove(atOffsets: $0) }

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

    // Standard initializer for adding a new medication
    init(onSave: @escaping (MedicationDraft) -> Void) {
        let resolvedVM = DIContainer.shared.resolve((any AddMedicationViewModelProtocol).self) as! VM
        self.init(viewModel: resolvedVM, isEditing: false, onSave: onSave)
    }

    // Initializer for editing an existing medication
    init(editingMedication: MedicationItem, onSave: @escaping (MedicationDraft) -> Void) {
        let resolvedVM = DIContainer.shared.resolve((any AddMedicationViewModelProtocol).self) as! VM

        // Copy data from the existing medication into the draft
        resolvedVM.draft.name = editingMedication.name
        resolvedVM.draft.formSystemImage = editingMedication.formSystemImage
        // Convert dosage if it's stored as a string; assign directly if it's already an Int
        resolvedVM.draft.dosage = Int(editingMedication.dosage)
        resolvedVM.draft.stockCount = editingMedication.stockCount
        resolvedVM.draft.lowStockThreshold = editingMedication.lowStockThreshold
        resolvedVM.draft.frequencyDays = editingMedication.frequencyDays
        resolvedVM.draft.timesOfDay = editingMedication.timesOfDay

        // Load the existing photo from disk. We populate draft.medicationImageData
        // here too (not just selectedImage) so that saving edits without changing
        // the photo isn't mistaken by DatabaseService for an explicit photo removal.
        if let imageData = ImageCache.shared.loadDataFromDisk(for: editingMedication.id) {
            resolvedVM.selectedImage = UIImage(data: imageData)
            resolvedVM.draft.medicationImageData = imageData
        }

        self.init(viewModel: resolvedVM, isEditing: true, onSave: onSave)
    }
}

#Preview {
    AddMedicationView(onSave: { _ in })
        .preferredColorScheme(.dark)
}
