//
//  DiaryCheckInView.swift
//  PillFlow
//
//  Created by Edward Gasparian on 24.08.2026.
//
//  Layout mirrors the "Daily Health & Mood Check-in" reference design 1:1
//  (sections, fields, sliders, chip grids), recolored to PillFlow's dark
//  theme (Color.bgDark / Color.cardDark / Color.neonMint) instead of the
//  reference's light card-on-white palette.
//

import SwiftUI

struct DiaryCheckInView<VM: DiaryCheckInViewModelProtocol>: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: VM

    @State private var customSymptomText = ""
    @State private var customMilestoneText = ""

    private let milestoneAccent = Color(red: 0.7, green: 0.4, blue: 0.9)
    private let allSymptomOptions = DiarySymptomOptions.all
    private let allMilestoneOptions = DiaryMilestoneOptions.all

    init(viewModel: @autoclosure @escaping () -> VM) {
        self._viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        ZStack {
            Color.bgDark.ignoresSafeArea()

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
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(Color.neonMint.opacity(0.15)).frame(width: 44, height: 44)
                Image(systemName: "face.smiling.fill")
                    .font(.title2)
                    .foregroundColor(.neonMint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Daily Health & Mood Check-in")
                    .font(.title3.weight(.bold))
                    .foregroundColor(.white)
                Text("Log how your body feels, mood scores & track visual progress")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(8)
                    .background(Color.white.opacity(0.08))
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
                    .colorScheme(.dark)
            }
            labeledField(title: "TIME") {
                DatePicker("", selection: $viewModel.draft.checkInDate, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .colorScheme(.dark)
            }
        }
    }

    private func labeledField<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2.weight(.heavy))
                .foregroundColor(.white.opacity(0.5))
                .tracking(0.5)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.cardDark)
                .cornerRadius(12)
        }
    }

    // MARK: - Mood

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("OVERALL MOOD TODAY")
                    .font(.caption.weight(.heavy))
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(0.5)
                Spacer()
                Text("SELECT DOMINANT MOOD")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.neonMint.opacity(0.8))
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
                    Text(mood.rawValue)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white)
                    Text("Score: \(mood.score)/5")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.neonMint.opacity(0.15) : Color.cardDark)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.neonMint : Color.white.opacity(0.06), lineWidth: isSelected ? 1.5 : 1)
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
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("ONE SENTENCE SUMMARY")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.neonMint.opacity(0.8))
            }

            TextField(
                "e.g., Clear-headed and relaxed, slight shoulder stiffness",
                text: $viewModel.draft.physicalSummary
            )
            .foregroundColor(.white)
            .padding(14)
            .background(Color.cardDark)
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
                tint: .neonMint,
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
        .background(Color.cardDark)
        .cornerRadius(18)
    }

    private var energyLabel: String {
        switch viewModel.draft.energyLevel {
        case ..<2: return "Low Energy"
        case 2...3: return "Moderate Energy"
        default: return "High Energy"
        }
    }

    private var discomfortLabel: String {
        switch viewModel.draft.discomfortLevel {
        case 0: return "Zero Pain"
        case 1...3: return "Mild"
        case 4...6: return "Manageable"
        default: return "Severe"
        }
    }

    private func sliderRow(
        icon: String, iconColor: Color, title: String, trailingLabel: String,
        value: Binding<Double>, range: ClosedRange<Double>, tint: Color,
        minLabel: String, midLabel: String, maxLabel: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: icon).foregroundColor(iconColor)
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white)
                }
                Spacer()
                Text(trailingLabel)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            Slider(value: value, in: range, step: 1)
                .tint(tint)
            HStack {
                Text(minLabel).font(.caption2).foregroundColor(.white.opacity(0.4))
                Spacer()
                Text(midLabel).font(.caption2).foregroundColor(.white.opacity(0.4))
                Spacer()
                Text(maxLabel).font(.caption2).foregroundColor(.white.opacity(0.4))
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
                        .foregroundColor(.white)
                }
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        TextField("7.5", value: $viewModel.draft.sleepHours, format: .number)
                            .keyboardType(.decimalPad)
                            .foregroundColor(.white)
                            .frame(width: 40)
                        Text("hours").foregroundColor(.white.opacity(0.5)).font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.bgDark)
                    .cornerRadius(10)

                    Spacer()

                    HStack(spacing: 6) {
                        ForEach(SleepQuality.allCases) { quality in
                            Button {
                                viewModel.draft.sleepQuality = quality
                            } label: {
                                Text(quality.rawValue)
                                    .font(.caption.weight(.heavy))
                                    .frame(width: 30, height: 30)
                                    .background(viewModel.draft.sleepQuality == quality ? Color.neonMint : Color.bgDark)
                                    .foregroundColor(viewModel.draft.sleepQuality == quality ? Color.bgDark : .white.opacity(0.6))
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
                        .foregroundColor(.white)
                }
                HStack {
                    Button {
                        if viewModel.draft.waterGlasses > 0 { viewModel.draft.waterGlasses -= 1 }
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 32, height: 32)
                            .background(Color.bgDark)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Spacer()
                    VStack(spacing: 2) {
                        Text("\(viewModel.draft.waterGlasses) glasses")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.white)
                        Text("(~\(viewModel.draft.waterGlasses * 250)ml)")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()

                    Button {
                        viewModel.draft.waterGlasses += 1
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 32, height: 32)
                            .background(Color.neonMint)
                            .foregroundColor(Color.bgDark)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .background(Color.cardDark)
        .cornerRadius(18)
    }

    // MARK: - Symptoms

    private var symptomsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PHYSICAL SYMPTOMS & SENSATIONS")
                .font(.caption.weight(.heavy))
                .foregroundColor(.white.opacity(0.6))

            FlowLayout(spacing: 10) {
                ForEach(allSymptomOptions, id: \.self) { symptom in
                    tagChip(
                        text: symptom,
                        isSelected: viewModel.draft.symptoms.contains(symptom),
                        accent: .neonMint,
                        prefix: "+"
                    ) {
                        viewModel.toggleSymptom(symptom)
                    }
                }
            }

            HStack(spacing: 10) {
                TextField("Add other symptom...", text: $customSymptomText)
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.cardDark)
                    .cornerRadius(12)

                Button("Add") {
                    viewModel.addCustomSymptom(customSymptomText)
                    customSymptomText = ""
                }
                .font(.subheadline.weight(.bold))
                .foregroundColor(Color.bgDark)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.neonMint)
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
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("SIDE EFFECTS, PROGRESS NOTES, GRATITUDE")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.neonMint.opacity(0.8))
                    .multilineTextAlignment(.trailing)
            }

            ZStack(alignment: .topLeading) {
                if viewModel.draft.reflectionNotes.isEmpty {
                    Text("Describe your day in detail: how your medications felt, energy shifts, dietary response, wellness milestones, or questions for your next doctor appointment...")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $viewModel.draft.reflectionNotes)
                    .scrollContentBackground(.hidden)
                    .foregroundColor(.white)
                    .padding(10)
                    .frame(minHeight: 120)
            }
            .background(Color.cardDark)
            .cornerRadius(14)
        }
    }

    // MARK: - Photos

    private var photosCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "camera.fill")
                        .foregroundColor(.neonMint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Progress Photos Tracking")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.white)
                        Text("Add photos to track skin changes, body posture, wellness milestones or recovery progress")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                Spacer()
                Text("\(viewModel.selectedImages.count) Attached")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.neonMint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.neonMint.opacity(0.12))
                    .cornerRadius(8)
            }

            Button {
                viewModel.showingPhotoSourceMenu = true
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.4))
                    Text("Click or drag photos here")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white.opacity(0.6))
                    Text("Supports mobile camera snapshots & image gallery (JPG, PNG, WebP)")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.35))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                        .foregroundColor(.white.opacity(0.15))
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
        .background(Color.cardDark)
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
                .foregroundColor(.white.opacity(0.6))

            FlowLayout(spacing: 10) {
                ForEach(allMilestoneOptions, id: \.self) { tag in
                    tagChip(
                        text: tag,
                        isSelected: viewModel.draft.milestoneTags.contains(tag),
                        accent: milestoneAccent,
                        prefix: "#"
                    ) {
                        viewModel.toggleMilestone(tag)
                    }
                }
            }

            HStack(spacing: 10) {
                TextField("Add custom milestone tag...", text: $customMilestoneText)
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.cardDark)
                    .cornerRadius(12)

                Button("Add") {
                    viewModel.addCustomMilestone(customMilestoneText)
                    customMilestoneText = ""
                }
                .font(.subheadline.weight(.bold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(milestoneAccent)
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
            .background(isSelected ? accent.opacity(0.9) : Color.cardDark)
            .foregroundColor(isSelected ? Color.bgDark : .white.opacity(0.8))
            .overlay(
                Capsule().stroke(isSelected ? Color.clear : Color.white.opacity(0.1), lineWidth: 1)
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
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.cardDark)
                    .cornerRadius(16)
            }
            .buttonStyle(.plain)

            Button(action: {
                viewModel.save()
                dismiss()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("RECORD DIARY CHECK-IN")
                }
                .font(.subheadline.weight(.heavy))
                .foregroundColor(Color.bgDark)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.neonMint)
                .cornerRadius(16)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Color.bgDark)
    }
}

extension DiaryCheckInView where VM == DiaryCheckInViewModel {
    init() {
        self.init(viewModel: DIContainer.shared.resolve((any DiaryCheckInViewModelProtocol).self) as! VM)
    }

    /// Opens the form pre-filled with an existing entry's data — saving then
    /// updates that entry in place instead of creating a new one. Mirrors
    /// AddMedicationView.init(editingMedication:).
    init(editingEntry: DiaryEntry) {
        let resolvedVM = DIContainer.shared.resolve((any DiaryCheckInViewModelProtocol).self) as! VM

        resolvedVM.draft.checkInDate = editingEntry.checkInDate
        resolvedVM.draft.mood = DiaryMood(rawValue: editingEntry.moodLabel) ?? .good
        resolvedVM.draft.physicalSummary = editingEntry.physicalSummary
        resolvedVM.draft.energyLevel = editingEntry.energyLevel
        resolvedVM.draft.discomfortLevel = editingEntry.discomfortLevel
        resolvedVM.draft.sleepHours = editingEntry.sleepHours
        resolvedVM.draft.sleepQuality = SleepQuality(rawValue: editingEntry.sleepQuality) ?? .good
        resolvedVM.draft.waterGlasses = editingEntry.waterGlasses
        resolvedVM.draft.symptoms = editingEntry.symptoms
        resolvedVM.draft.reflectionNotes = editingEntry.reflectionNotes
        resolvedVM.draft.milestoneTags = editingEntry.milestoneTags

        // Load the existing photos from disk so saving without touching them
        // isn't mistaken for removing them all (same reasoning as
        // AddMedicationView.init(editingMedication:)).
        var loadedImages: [UIImage] = []
        var loadedData: [Data] = []
        for photoId in editingEntry.photoIds {
            if let data = ImageCache.shared.loadDataFromDisk(for: photoId), let image = UIImage(data: data) {
                loadedImages.append(image)
                loadedData.append(data)
            }
        }
        resolvedVM.selectedImages = loadedImages
        resolvedVM.draft.photos = loadedData

        resolvedVM.editingEntry = editingEntry

        self.init(viewModel: resolvedVM)
    }
}

#Preview {
    DiaryCheckInView(viewModel: MockDiaryCheckInViewModel())
        .preferredColorScheme(.dark)
}
