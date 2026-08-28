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
                    .font(.title3.weight(.bold))
                    .foregroundColor(.textPrimary)
                Text("Log how your body feels, mood scores & track visual progress")
                    .font(.caption)
                    .foregroundColor(.textPrimary.opacity(0.5))
            }

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.textPrimary.opacity(0.6))
                    .padding(8)
                    .background(Color.textPrimary.opacity(0.08))
                    .clipShape(Circle())
            }
        }
        .padding()
    }

    // MARK: - Date / Time

    private var dateTimeSection: some View {
        HStack(spacing: 12) {
            labeledField(title: "CHECK-IN DATE") {
                DatePicker("", selection: $viewModel.draft.checkInDate, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .appColorScheme()
            }
            labeledField(title: "TIME") {
                DatePicker("", selection: $viewModel.draft.checkInDate, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .appColorScheme()
            }
        }
    }

    private func labeledField<Content: View>(title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2.weight(.heavy))
                .foregroundColor(.textPrimary.opacity(0.5))
                .tracking(0.5)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
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
                    .foregroundColor(.textPrimary.opacity(0.6))
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
                        .foregroundColor(.textPrimary.opacity(0.5))
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
                    .foregroundColor(.textPrimary.opacity(0.6))
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
                    .foregroundColor(.textPrimary.opacity(0.5))
            }
            Slider(value: value, in: range, step: 1)
                .tint(tint)
            HStack {
                // Three labels share one row ("0 (None) / 5 (Manageable) / 10 (Severe)");
                // the middle one is noticeably longer in German and Romanian.
                Text(minLabel).font(.caption2).foregroundColor(.textPrimary.opacity(0.4))
                    .lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                Text(midLabel).font(.caption2).foregroundColor(.textPrimary.opacity(0.4))
                    .lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                Text(maxLabel).font(.caption2).foregroundColor(.textPrimary.opacity(0.4))
                    .lineLimit(1).minimumScaleFactor(0.8)
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
                        Text("hours").foregroundColor(.textPrimary.opacity(0.5)).font(.caption)
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
                                    .foregroundColor(viewModel.draft.sleepQuality == quality ? Color.onAccent : .textPrimary.opacity(0.6))
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

                    Spacer()
                    VStack(spacing: 2) {
                        Text("\(viewModel.draft.waterGlasses) glasses")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.textPrimary)
                        Text("(~\(viewModel.draft.waterGlasses * 250)ml)")
                            .font(.caption2)
                            .foregroundColor(.textPrimary.opacity(0.5))
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
                .foregroundColor(.textPrimary.opacity(0.6))

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
                .background(Color.accentPrimary)
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Reflection

    private var reflectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("PERSONAL REFLECTION & DIARY NOTES")
                    .font(.caption.weight(.heavy))
                    .foregroundColor(.textPrimary.opacity(0.6))
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
                        .foregroundColor(.textPrimary.opacity(0.3))
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
                            .foregroundColor(.textPrimary.opacity(0.5))
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
                        .foregroundColor(.textPrimary.opacity(0.4))
                    Text("Click or drag photos here")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.textPrimary.opacity(0.6))
                    Text("Supports mobile camera snapshots & image gallery (JPG, PNG, WebP)")
                        .font(.caption2)
                        .foregroundColor(.textPrimary.opacity(0.35))
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

                                Button {
                                    withAnimation { viewModel.removePhoto(at: index) }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white)
                                        .background(Circle().fill(Color.black.opacity(0.6)))
                                }
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
                .foregroundColor(.textPrimary.opacity(0.6))

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
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.milestonePurple)
                .cornerRadius(12)
            }
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
        HStack(spacing: 12) {
            Button(action: { dismiss() }) {
                Text("CANCEL")
                    .font(.subheadline.weight(.heavy))
                    .foregroundColor(.textPrimary.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
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
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.accentPrimary)
                .cornerRadius(16)
            }
            .buttonStyle(.plain)
        }
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
