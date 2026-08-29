//
//  DiaryCheckInView.swift
//  PillFlow
//
//  Created by Edward Gasparian on 24.08.2026.
//
//  Layout mirrors the "Daily Health & Mood Check-in" reference design 1:1
//  (sections, fields, sliders, chip grids), recolored to PillFlow's dark
//  theme (Color.appBackground / Color.appSurface / Color.accentPrimary) instead of the
//  reference's light card-on-white palette.
//

import SwiftUI

struct DiaryCheckInView<VM: DiaryCheckInViewModelProtocol>: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: VM

    @State private var customSymptomText = ""
    @State private var customMilestoneText = ""

    /// Separate flags rather than one enum: each popover anchors to its own
    /// field, which is what puts the arrow under the value being edited.
    @State private var showingDatePicker = false
    @State private var showingTimePicker = false

    private let allSymptomOptions = DiarySymptomOptions.all
    private let allMilestoneOptions = DiaryMilestoneOptions.all

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
                        moodSection
                        physicalSummarySection
                        energyDiscomfortCard
                        sleepWaterCard
                        symptomsSection
                        reflectionSection
                        photosCard
                        milestonesSection
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
            labeledField(title: "CHECK-IN DATE") {
                valueButton(
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
            labeledField(title: "TIME") {
                valueButton(
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

    /// The date or time value as plain text, tappable across the whole field.
    ///
    /// The compact `DatePicker` paints its own grey capsule and SwiftUI offers
    /// no way to turn that off. Hiding it under a transparent overlay does not
    /// work either — it stops receiving touches — so the value is drawn as text
    /// and the picker moved into a popover this opens.
    private func valueButton(text: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(text)
    }

    private func labeledField<Content: View>(title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2.weight(.heavy))
                .foregroundColor(.textSecondary)
                .tracking(0.5)
            content()
                // Centred, not leading: the compact DatePicker renders as a pill
                // that hugs its text, so aligning it leading left it floating in
                // the corner of a much wider box.
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.appSurface)
                .cornerRadius(12)
        }
    }

    // MARK: - Mood

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("OVERALL MOOD TODAY")
                    .font(.caption.weight(.heavy))
                    .foregroundColor(.textSecondary)
                    .tracking(0.5)
                Spacer()
                Text("SELECT DOMINANT MOOD")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.accentPrimary.opacity(0.8))
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(DiaryMood.allCases) { mood in
                    moodCard(mood)
                }
            }
        }
    }

    private func moodCard(_ mood: DiaryMood) -> some View {
        let isSelected = viewModel.draft.mood == mood
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.draft.mood = mood
            }
        } label: {
            HStack(spacing: 12) {
                Text(mood.emoji).font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(mood.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.textPrimary)
                    Text("Score: \(mood.score)/5")
                        .font(.caption2)
                        .foregroundColor(.textSecondary)
                }
                Spacer()
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.accentPrimary.opacity(0.15) : Color.appSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.accentPrimary : Color.textPrimary.opacity(0.06), lineWidth: isSelected ? 1.5 : 1)
            )
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
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

    // MARK: - Energy / Discomfort

    private var energyDiscomfortCard: some View {
        VStack(spacing: 20) {
            sliderRow(
                icon: "bolt.fill",
                iconColor: .yellow,
                title: "Energy Level: \(viewModel.draft.energyLevel)/5",
                trailingLabel: energyLabel,
                value: Binding(
                    get: { Double(viewModel.draft.energyLevel) },
                    set: { viewModel.draft.energyLevel = Int($0.rounded()) }
                ),
                range: 1...5,
                tint: .accentPrimary,
                minLabel: "Low", midLabel: "Moderate", maxLabel: "Peak"
            )

            Divider().opacity(0.15)

            sliderRow(
                icon: "heart.fill",
                iconColor: .pink,
                title: "Discomfort/Pain: \(viewModel.draft.discomfortLevel)/10",
                trailingLabel: discomfortLabel,
                value: Binding(
                    get: { Double(viewModel.draft.discomfortLevel) },
                    set: { viewModel.draft.discomfortLevel = Int($0.rounded()) }
                ),
                range: 0...10,
                tint: .pink,
                minLabel: "0 (None)", midLabel: "5 (Manageable)", maxLabel: "10 (Severe)"
            )
        }
        .padding(18)
        .background(Color.appSurface)
        .cornerRadius(18)
    }

    private var energyLabel: LocalizedStringKey {
        switch viewModel.draft.energyLevel {
        case ..<2: return "Low Energy"
        case 2...3: return "Moderate Energy"
        default: return "High Energy"
        }
    }

    private var discomfortLabel: LocalizedStringKey {
        switch viewModel.draft.discomfortLevel {
        case 0: return "Zero Pain"
        case 1...3: return "Mild"
        case 4...6: return "Manageable"
        default: return "Severe"
        }
    }

    private func sliderRow(
        icon: String, iconColor: Color, title: LocalizedStringKey, trailingLabel: LocalizedStringKey,
        value: Binding<Double>, range: ClosedRange<Double>, tint: Color,
        minLabel: LocalizedStringKey, midLabel: LocalizedStringKey, maxLabel: LocalizedStringKey
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: icon).foregroundColor(iconColor)
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.textPrimary)
                }
                Spacer()
                Text(trailingLabel)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            Slider(value: value, in: range, step: 1)
                .tint(tint)
            HStack {
                // Three labels share one row ("0 (None) / 5 (Manageable) / 10 (Severe)");
                // the middle one is noticeably longer in German and Romanian.
                Text(minLabel).font(.caption2).foregroundColor(.textSecondary)
                    .lineLimit(2).minimumScaleFactor(0.9)
                Spacer(minLength: 4)
                Text(midLabel).font(.caption2).foregroundColor(.textSecondary)
                    .lineLimit(2).minimumScaleFactor(0.9)
                Spacer(minLength: 4)
                Text(maxLabel).font(.caption2).foregroundColor(.textSecondary)
                    .lineLimit(2).minimumScaleFactor(0.9)
            }
        }
    }

    // MARK: - Sleep / Water

    private var sleepWaterCard: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "moon.stars.fill").foregroundColor(.purple)
                    Text("Sleep Duration & Quality")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.textPrimary)
                }
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        // The field used to accept anything — negative values,
                        // dozens of hours — and those numbers fed the averages.
                        TextField("7.5", value: Binding(
                            get: { viewModel.draft.sleepHours },
                            set: { viewModel.draft.sleepHours = min(max($0, 0), 24) }
                        ), format: .number)
                            .keyboardType(.decimalPad)
                            .foregroundColor(.textPrimary)
                            .frame(width: 40)
                        Text("hours").foregroundColor(.textSecondary).font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.appBackground)
                    .cornerRadius(10)

                    Spacer()

                    HStack(spacing: 6) {
                        ForEach(SleepQuality.allCases) { quality in
                            Button {
                                viewModel.draft.sleepQuality = quality
                            } label: {
                                Text(quality.initial)
                                    .font(.caption.weight(.heavy))
                                    .frame(width: 30, height: 30)
                                    .background(viewModel.draft.sleepQuality == quality ? Color.accentPrimary : Color.appBackground)
                                    .foregroundColor(viewModel.draft.sleepQuality == quality ? Color.onAccent : .textSecondary)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Divider().opacity(0.15)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "drop.fill").foregroundColor(.blue)
                    Text("Water Hydration")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.textPrimary)
                }
                HStack {
                    Button {
                        if viewModel.draft.waterGlasses > 0 { viewModel.draft.waterGlasses -= 1 }
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 32, height: 32)
                            .background(Color.appBackground)
                            .foregroundColor(.textPrimary)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .expandTouchTarget(6)

                    Spacer()
                    VStack(spacing: 2) {
                        Text("\(viewModel.draft.waterGlasses) glasses")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.textPrimary)
                        Text("(~\(viewModel.draft.waterGlasses * 250)ml)")
                            .font(.caption2)
                            .foregroundColor(.textSecondary)
                    }
                    Spacer()

                    Button {
                        viewModel.draft.waterGlasses += 1
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 32, height: 32)
                            .background(Color.accentPrimary)
                            .foregroundColor(Color.onAccent)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .expandTouchTarget(6)
                }
            }
        }
        .padding(18)
        .background(Color.appSurface)
        .cornerRadius(18)
    }

    // MARK: - Symptoms

    private var symptomsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PHYSICAL SYMPTOMS & SENSATIONS")
                .font(.caption.weight(.heavy))
                .foregroundColor(.textSecondary)

            FlowLayout(spacing: 10) {
                ForEach(allSymptomOptions, id: \.self) { symptom in
                    tagChip(
                        text: DiarySymptomOptions.title(for: symptom),
                        isSelected: viewModel.draft.symptoms.contains(symptom),
                        accent: .accentPrimary,
                        prefix: "+"
                    ) {
                        viewModel.toggleSymptom(symptom)
                    }
                }
            }

            HStack(spacing: 10) {
                TextField("Add other symptom...", text: $customSymptomText)
                    .foregroundColor(.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.appSurface)
                    .cornerRadius(12)

                Button("Add") {
                    viewModel.addCustomSymptom(customSymptomText)
                    customSymptomText = ""
                }
                .font(.subheadline.weight(.bold))
                .foregroundColor(Color.onAccent)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxHeight: .infinity)
                .background(Color.accentPrimary)
                .cornerRadius(12)
                .contentShape(Rectangle())
            }
            .fixedSize(horizontal: false, vertical: true)
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

    // MARK: - Photos

    private var photosCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "camera.fill")
                        .foregroundColor(.accentPrimary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Progress Photos Tracking")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.textPrimary)
                        Text("Add photos to track skin changes, body posture, wellness milestones or recovery progress")
                            .font(.caption2)
                            .foregroundColor(.textSecondary)
                    }
                }
                Spacer()
                Text("\(viewModel.selectedImages.count) Attached")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.accentPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentPrimary.opacity(0.12))
                    .cornerRadius(8)
            }

            Button {
                viewModel.showingPhotoSourceMenu = true
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title2)
                        .foregroundColor(.textTertiary)
                    Text("Click or drag photos here")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.textSecondary)
                    Text("Supports mobile camera snapshots & image gallery (JPG, PNG, WebP)")
                        .font(.caption2)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                        .foregroundColor(.textPrimary.opacity(0.15))
                )
            }
            .buttonStyle(.plain)

            if !viewModel.selectedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(viewModel.selectedImages.enumerated()), id: \.offset) { index, image in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 72, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))

                                // The thumbnail itself has no tap action, so the
                                // 44pt target can grow inward over the photo: the
                                // glyph stays pinned in the corner where it was and
                                // there is nothing underneath to hit by mistake.
                                Button {
                                    withAnimation { viewModel.removePhoto(at: index) }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.white)
                                        .background(Circle().fill(Color.black.opacity(0.6)))
                                        .frame(width: 44, height: 44, alignment: .topTrailing)
                                        .contentShape(Rectangle())
                                }
                                .accessibilityLabel("Remove photo")
                                .padding(4)
                            }
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(Color.appSurface)
        .cornerRadius(18)
        .confirmationDialog("Add Photo", isPresented: $viewModel.showingPhotoSourceMenu, titleVisibility: .visible) {
            Button("Take Photo (Camera)") {
                viewModel.requestImageSelection(source: .camera)
            }
            Button("Choose from Library") {
                viewModel.requestImageSelection(source: .photoLibrary)
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Milestones

    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TAGS & MILESTONES")
                .font(.caption.weight(.heavy))
                .foregroundColor(.textSecondary)

            FlowLayout(spacing: 10) {
                ForEach(allMilestoneOptions, id: \.self) { tag in
                    tagChip(
                        text: DiaryMilestoneOptions.title(for: tag),
                        isSelected: viewModel.draft.milestoneTags.contains(tag),
                        accent: .milestonePurple,
                        prefix: "#"
                    ) {
                        viewModel.toggleMilestone(tag)
                    }
                }
            }

            HStack(spacing: 10) {
                TextField("Add custom milestone tag...", text: $customMilestoneText)
                    .foregroundColor(.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.appSurface)
                    .cornerRadius(12)

                Button("Add") {
                    viewModel.addCustomMilestone(customMilestoneText)
                    customMilestoneText = ""
                }
                .font(.subheadline.weight(.bold))
                .foregroundColor(Color.onAccent)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxHeight: .infinity)
                .background(Color.accentPrimary)
                .cornerRadius(12)
                .contentShape(Rectangle())
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Shared tag chip

    private func tagChip(text: String, isSelected: Bool, accent: Color, prefix: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(isSelected ? "✓" : prefix)
                Text(text)
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? accent.opacity(0.9) : Color.appSurface)
            .foregroundColor(isSelected ? Color.onAccent : .textPrimary.opacity(0.8))
            .overlay(
                Capsule().stroke(isSelected ? Color.clear : Color.textPrimary.opacity(0.1), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
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

extension DiaryCheckInView where VM == DiaryCheckInViewModel {
    init() {
        self.init(viewModel: DIContainer.shared.resolve(DiaryCheckInViewModel.self))
    }

    /// Opens the form on an existing entry: saving updates it rather than
    /// creating a new one. The draft itself is filled by `startEditing(_:)`
    /// from `.task`.
    init(editingEntry: DiaryEntry) {
        self.init(
            viewModel: DIContainer.shared.resolve(DiaryCheckInViewModel.self),
            editingEntry: editingEntry
        )
    }
}

#Preview {
    DiaryCheckInView(viewModel: MockDiaryCheckInViewModel())
        .appTheme()
}
