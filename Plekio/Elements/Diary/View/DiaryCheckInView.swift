//
//  DiaryCheckInView.swift
//  Plekio
//
//  Created by Edward Gasparian on 24.08.2026.
//
//  Layout mirrors the "Daily Health & Mood Check-in" reference design 1:1
//  (sections, fields, sliders, chip grids), recolored to Plekio's dark
//  theme (Color.appBackground / Color.appSurface / Color.accentPrimary) instead of the
//  reference's light card-on-white palette.
//
//  The sections themselves live in DiaryCheckIn*.swift alongside this file.
//  What is left here is the form's own business: which sections there are, in
//  what order, what each one is bound to, and how the whole thing is saved.
//

import SwiftUI

struct DiaryCheckInView<VM: DiaryCheckInViewModelProtocol>: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: VM
    
    /// Separate flags rather than one enum: each popover anchors to its own
    /// field, which is what puts the arrow under the value being edited.
    @State private var showingDatePicker = false
    @State private var showingTimePicker = false
    
    /// The entry being edited, or nil when creating a new one. Consumed in
    /// `.task` rather than `init`: SwiftUI re-creates the view struct many
    /// times, so any work done in the initializer runs again each time.
    private let entryToEdit: DiaryEntry?
    
    init(viewModel: @autoclosure @escaping () -> VM, editingEntry: DiaryEntry? = nil) {
        self._viewModel = StateObject(wrappedValue: viewModel())
        self.entryToEdit = editingEntry
    }
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                header
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        dateTimeSection
                        
                        DiaryMoodGrid(selection: $viewModel.draft.mood)
                        
                        physicalSummarySection
                        
                        DiaryEnergyDiscomfortCard(
                            energyLevel: $viewModel.draft.energyLevel,
                            discomfortLevel: $viewModel.draft.discomfortLevel,
                            energyDescription: viewModel.draft.energyDescription,
                            discomfortDescription: viewModel.draft.discomfortDescription
                        )
                        
                        DiarySleepWaterCard(
                            sleepHours: $viewModel.draft.sleepHours,
                            sleepQuality: $viewModel.draft.sleepQuality,
                            waterGlasses: $viewModel.draft.waterGlasses
                        )
                        
                        DiaryTagSection(
                            title: "PHYSICAL SYMPTOMS & SENSATIONS",
                            options: DiarySymptomOptions.all,
                            displayName: { DiarySymptomOptions.title(for: $0) },
                            isSelected: { viewModel.isSymptomSelected($0) },
                            accent: .accentPrimary,
                            prefix: "+",
                            inputPlaceholder: "Add other symptom...",
                            onToggle: { viewModel.toggleSymptom($0) },
                            onAddCustom: { viewModel.addCustomSymptom($0) }
                        )
                        
                        reflectionSection
                        
                        DiaryPhotosCard(
                            images: viewModel.selectedImages,
                            showingSourceMenu: $viewModel.showingPhotoSourceMenu,
                            onRemove: { viewModel.removePhoto(at: $0) },
                            onPick: { viewModel.requestImageSelection(source: $0) }
                        )
                        
                        DiaryTagSection(
                            title: "TAGS & MILESTONES",
                            options: DiaryMilestoneOptions.all,
                            displayName: { DiaryMilestoneOptions.title(for: $0) },
                            isSelected: { viewModel.isMilestoneSelected($0) },
                            accent: .milestonePurple,
                            prefix: "#",
                            inputPlaceholder: "Add custom milestone tag...",
                            onToggle: { viewModel.toggleMilestone($0) },
                            onAddCustom: { viewModel.addCustomMilestone($0) }
                        )
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
                
                bottomBar
            }
        }
        .task {
            guard let entryToEdit else { return }
            await viewModel.startEditing(entryToEdit)
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(Color.accentPrimary.opacity(0.15)).frame(width: 44, height: 44)
                Image(systemName: "face.smiling.fill")
                    .font(.title2)
                    .foregroundColor(.accentPrimary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Daily Health & Mood Check-in")
                    .font(.system(.title3, design: .serif, weight: .bold))
                    .foregroundColor(.textPrimary)
                Text("Log how your body feels, mood scores & track visual progress")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            
            Spacer()
            
        }
        .padding()
    }
    
    // MARK: - Date / Time
    
    private var dateTimeSection: some View {
        HStack(alignment: .center, spacing: 12) {
            DiaryLabeledField(title: "CHECK-IN DATE") {
                DiaryValueButton(
                    text: viewModel.draft.checkInDate.formatted(date: .abbreviated, time: .omitted),
                    label: "CHECK-IN DATE"
                ) { showingDatePicker = true }
                    .popover(isPresented: $showingDatePicker) {
                        // A popover sizes itself to its content, and the graphical
                        // picker has no width of its own to offer — left to itself it
                        // collapsed into a column two digits wide. A month grid needs
                        // roughly 320pt, which still fits inside a popover on the
                        // narrowest phone iOS 26 runs on.
                        DatePicker("", selection: $viewModel.draft.checkInDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .labelsHidden()
                            .frame(width: 320)
                            .padding(8)
                            .presentationCompactAdaptation(.popover)
                            .appColorScheme()
                    }
            }
            DiaryLabeledField(title: "TIME") {
                DiaryValueButton(
                    text: viewModel.draft.checkInDate.formatted(date: .omitted, time: .shortened),
                    label: "TIME"
                ) { showingTimePicker = true }
                    .popover(isPresented: $showingTimePicker) {
                        DatePicker("", selection: $viewModel.draft.checkInDate, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .padding()
                            .presentationCompactAdaptation(.popover)
                            .appColorScheme()
                    }
            }
        }
    }
    
    // MARK: - Physical Summary
    
    private var physicalSummarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("HOW ARE YOU FEELING PHYSICALLY TODAY?")
                    .font(.caption.weight(.heavy))
                    .foregroundColor(.textSecondary)
                Spacer()
                Text("ONE SENTENCE SUMMARY")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.accentPrimary.opacity(0.8))
            }
            
            TextField(
                "e.g., Clear-headed and relaxed, slight shoulder stiffness",
                text: $viewModel.draft.physicalSummary
            )
            .foregroundColor(.textPrimary)
            .padding(14)
            .background(Color.appSurface)
            .cornerRadius(14)
        }
    }
    
    // MARK: - Reflection
    
    private var reflectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("PERSONAL REFLECTION & DIARY NOTES")
                    .font(.caption.weight(.heavy))
                    .foregroundColor(.textSecondary)
                Spacer()
                Text("SIDE EFFECTS, PROGRESS NOTES, GRATITUDE")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.accentPrimary.opacity(0.8))
                    .multilineTextAlignment(.trailing)
            }
            
            ZStack(alignment: .topLeading) {
                if viewModel.draft.reflectionNotes.isEmpty {
                    Text("Describe your day in detail: how your medications felt, energy shifts, dietary response, wellness milestones, or questions for your next doctor appointment...")
                        .font(.subheadline)
                        .foregroundColor(.textTertiary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $viewModel.draft.reflectionNotes)
                    .scrollContentBackground(.hidden)
                    .foregroundColor(.textPrimary)
                    .padding(10)
                    .frame(minHeight: 120)
            }
            .background(Color.appSurface)
            .cornerRadius(14)
        }
    }
    
    // MARK: - Bottom Bar
    
    private var bottomBar: some View {
        // The confirm label wraps to two lines in most languages while "Cancel"
        // never does, so both stretch to the row and the row takes the taller.
        HStack(spacing: 12) {
            Button(action: { dismiss() }) {
                Text("CANCEL")
                    .font(.subheadline.weight(.heavy))
                    .foregroundColor(.textPrimary.opacity(0.7))
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.appSurface)
                    .cornerRadius(16)
            }
            .buttonStyle(.plain)
            
            Button(action: {
                if viewModel.save() { dismiss() }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("RECORD DIARY CHECK-IN")
                }
                .font(.subheadline.weight(.heavy))
                .foregroundColor(Color.onAccent)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.accentPrimary)
                .cornerRadius(16)
            }
            .buttonStyle(.plain)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Color.appBackground)
    }
}

#Preview {
    DiaryCheckInView(viewModel: MockDiaryCheckInViewModel())
        .appTheme()
}
