//
//  BeforeAfterComparisonView.swift
//  PillFlow
//
//  Created by Edward Gasparian on 24.08.2026.
//
//  Before/after comparison: two modes (split slider and side by side),
//  checkpoint pickers, and a strip of every available photo. A 400+ line
//  screen that used to live at the end of DiaryView.swift.
//

import SwiftUI

// MARK: - Before / After comparison

struct BeforeAfterComparisonView: View {
    /// Every photo available to compare against, across all diary entries
    /// (not just the current gallery category filter).
    let checkpoints: [DiaryPhotoCheckpoint]

    @State private var beforePhotoId: UUID
    @State private var afterPhotoId: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var beforeImage: UIImage?
    @State private var afterImage: UIImage?
    @State private var sliderPosition: CGFloat = 0.5
    @State private var mode: ComparisonMode = .splitSlider
    @State private var pickerTarget: ComparisonSlot?

    private enum ComparisonMode { case sideBySide, splitSlider }

    private enum ComparisonSlot: Identifiable {
        case before, after
        var id: Self { self }
    }

    private static let dateLabelStyle = Date.FormatStyle(date: .abbreviated, time: .omitted)

    init(checkpoints: [DiaryPhotoCheckpoint], beforePhotoId: UUID, afterPhotoId: UUID) {
        self.checkpoints = checkpoints
        self._beforePhotoId = State(initialValue: beforePhotoId)
        self._afterPhotoId = State(initialValue: afterPhotoId)
    }

    private var beforeCheckpoint: DiaryPhotoCheckpoint? { checkpoints.first { $0.id == beforePhotoId } }
    private var afterCheckpoint: DiaryPhotoCheckpoint? { checkpoints.first { $0.id == afterPhotoId } }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    header

                    photoSelectorRow(label: "BEFORE PHOTO (A):", tint: .accentPrimary, checkpoint: beforeCheckpoint) {
                        pickerTarget = .before
                    }
                    photoSelectorRow(label: "AFTER PHOTO (B):", tint: .warmAccent, checkpoint: afterCheckpoint) {
                        pickerTarget = .after
                    }

                    switch mode {
                    case .splitSlider: splitSliderView
                    case .sideBySide: sideBySideView
                    }

                    availablePhotosSection
                }
                .padding(.horizontal)
                .padding(.vertical)
            }
        }
        // `.task(id:)` restarts itself when the id changes, which replaces an
        // onAppear plus two onChange handlers.
        .task(id: beforePhotoId) { beforeImage = await ImageCache.shared.image(for: beforePhotoId) }
        .task(id: afterPhotoId) { afterImage = await ImageCache.shared.image(for: afterPhotoId) }
        .sheet(item: $pickerTarget) { slot in
            photoPickerSheet(for: slot)
        }
    }

    // MARK: Header + mode toggle

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(Color.accentPrimary.opacity(0.15)).frame(width: 40, height: 40)
                Image(systemName: "arrow.left.arrow.right")
                    .font(.subheadline)
                    .foregroundColor(.accentPrimary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Visual Progress Comparison")
                    .scaledFont(size: 18, relativeTo: .headline, weight: .bold, design: .serif)
                    .foregroundColor(.textPrimary)
                Text("Track your recovery, skin changes & wellness transformation")
                    .font(.caption2)
                    .foregroundColor(.textSecondary)
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 8) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.textPrimary.opacity(0.7))
                        .padding(7)
                        .background(Color.textPrimary.opacity(0.08))
                        .clipShape(Circle())
                }
                .expandTouchTarget(10)
                modeToggle
            }
        }
    }

    private var modeToggle: some View {
        HStack(spacing: 4) {
            // The line break is no longer baked into the string — it would land in
            // the wrong place in another language. lineLimit(2) wraps it instead.
            modeButton("Side by Side", isActive: mode == .sideBySide) { mode = .sideBySide }
            modeButton("Split Slider", isActive: mode == .splitSlider) { mode = .splitSlider }
        }
    }

    private func modeButton(_ title: LocalizedStringKey, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption2.weight(.bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundColor(isActive ? Color.onAccent : .textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(minWidth: 56)
                .background(isActive ? Color.accentPrimary : Color.textPrimary.opacity(0.06))
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    // MARK: Photo selector rows + picker sheet

    private func photoSelectorRow(label: LocalizedStringKey, tint: Color, checkpoint: DiaryPhotoCheckpoint?, action: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.caption2.weight(.heavy))
                .foregroundColor(tint)
                .frame(width: 96, alignment: .leading)

            Button(action: action) {
                HStack {
                    Text(captionText(for: checkpoint))
                        .font(.caption)
                        .foregroundColor(.textPrimary.opacity(0.85))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 6)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.textTertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.appSurface)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
    }

    private func captionText(for checkpoint: DiaryPhotoCheckpoint?) -> String {
        guard let checkpoint else { return "Select a photo" }
        let dateText = checkpoint.entry.checkInDate.formatted(Self.dateLabelStyle)
        let notes = checkpoint.entry.displayCaption
        return notes.isEmpty ? dateText : "\(dateText) • \(notes)"
    }

    private func photoPickerSheet(for slot: ComparisonSlot) -> some View {
        NavigationStack {
            List(checkpoints) { item in
                let isSelected = slot == .before ? item.id == beforePhotoId : item.id == afterPhotoId
                Button {
                    switch slot {
                    case .before: beforePhotoId = item.id
                    case .after: afterPhotoId = item.id
                    }
                    pickerTarget = nil
                } label: {
                    HStack {
                        Text(captionText(for: item))
                            .font(.subheadline)
                            .foregroundColor(.textPrimary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                            .foregroundColor(.accentPrimary)
                    }
                }
                .listRowBackground(Color.appSurface)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle(slot == .before ? "Select Before Photo" : "Select After Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { pickerTarget = nil }
                }
            }
        }
        .appTheme()
        .presentationDetents([.medium, .large])
    }

    // MARK: Split slider mode

    private var splitSliderView: some View {
        VStack(spacing: 12) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    if let afterImage {
                        Image(uiImage: afterImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    } else {
                        Color.textPrimary.opacity(0.05)
                    }
                    if let beforeImage {
                        Image(uiImage: beforeImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                            .mask(alignment: .leading) {
                                Rectangle().frame(width: geo.size.width * sliderPosition)
                            }
                    }

                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 2)
                        .position(x: geo.size.width * sliderPosition, y: geo.size.height / 2)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "arrow.left.and.right")
                                .font(.caption)
                                .foregroundColor(.black)
                        )
                        .position(x: geo.size.width * sliderPosition, y: geo.size.height / 2)
                        .gesture(
                            DragGesture().onChanged { value in
                                sliderPosition = min(max(value.location.x / geo.size.width, 0), 1)
                            }
                        )

                    VStack {
                        HStack {
                            tag("BEFORE (\(shortDate(beforeCheckpoint)))", tint: .accentPrimary)
                            Spacer()
                            tag("AFTER (\(shortDate(afterCheckpoint)))", tint: .warmAccent)
                        }
                        .padding(12)
                        Spacer()
                    }
                }
            }
            .frame(height: 380)
            .cornerRadius(20)

            HStack(spacing: 12) {
                Text("Before")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.accentPrimary)
                Slider(value: $sliderPosition)
                    .tint(.white)
                Text("After")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.warmAccent)
            }
        }
    }

    private func tag(_ text: LocalizedStringKey, tint: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.heavy))
            .foregroundColor(Color.onAccent)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint)
            .clipShape(Capsule())
    }

    private func shortDate(_ checkpoint: DiaryPhotoCheckpoint?) -> String {
        guard let checkpoint else { return "--" }
        return checkpoint.entry.checkInDate.formatted(Self.dateLabelStyle)
    }

    // MARK: Side by side mode

    private var sideBySideView: some View {
        VStack(spacing: 16) {
            stateCard(title: "STATE A (EARLIER BASELINE)", tint: .accentPrimary, checkpoint: beforeCheckpoint, image: beforeImage)
            stateCard(title: "STATE B (RECENT / PROGRESS)", tint: .warmAccent, checkpoint: afterCheckpoint, image: afterImage)
        }
    }

    private func stateCard(title: LocalizedStringKey, tint: Color, checkpoint: DiaryPhotoCheckpoint?, image: UIImage?) -> some View {
        let boldLine = checkpoint?.entry.milestoneTags.first ?? checkpoint?.entry.physicalSummary ?? ""
        let quote = checkpoint?.entry.displayCaption ?? ""

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.caption2.weight(.heavy))
                    .foregroundColor(Color.onAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(tint)
                    .clipShape(Capsule())
                Spacer()
                Text(shortDate(checkpoint))
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }

            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.textPrimary.opacity(0.05)
                }
            }
            .frame(height: 220)
            .frame(maxWidth: .infinity)
            .clipped()
            .cornerRadius(14)

            if !boldLine.isEmpty {
                Text(boldLine)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.textPrimary.opacity(0.9))
            }
            if !quote.isEmpty && quote != boldLine {
                Text(quote)
                    .font(.caption.italic())
                    .foregroundColor(.textSecondary)
                    .lineLimit(2)
            }
            if let checkpoint {
                Text("Mood: \(checkpoint.entry.moodTitle)")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(tint)
            }
        }
        .padding(14)
        .background(Color.appSurface)
        .cornerRadius(18)
    }

    // MARK: Available photos strip

    private var availablePhotosSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AVAILABLE PROGRESS PHOTOS (\(checkpoints.count))")
                .font(.caption2.weight(.heavy))
                .foregroundColor(.textSecondary)
                .tracking(0.5)

            ScrollView(.horizontal, showsIndicators: false) {
                // Lazy: this strip lists every photo across the whole diary,
                // not just the current gallery filter — with a long history
                // a plain HStack would decode every thumbnail up front.
                LazyHStack(spacing: 10) {
                    ForEach(checkpoints) { item in
                        comparisonThumbnail(item)
                    }
                }
            }
        }
    }

    private func comparisonThumbnail(_ item: DiaryPhotoCheckpoint) -> some View {
        let isBefore = item.id == beforePhotoId
        let isAfter = item.id == afterPhotoId

        return VStack(spacing: 4) {
            DiaryAsyncPhoto(photoId: item.id)
                .frame(width: 76, height: 76)
                .clipped()
                .cornerRadius(12)
                .overlay(alignment: .topLeading) {
                    if isBefore { slotBadge("A", tint: .accentPrimary) }
                }
                .overlay(alignment: .topTrailing) {
                    if isAfter { slotBadge("B", tint: .warmAccent) }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke((isBefore || isAfter) ? Color.accentPrimary.opacity(0.8) : Color.clear, lineWidth: 2)
                )

            Text(item.entry.checkInDate.formatted(Self.dateLabelStyle))
                .font(.caption2)
                .foregroundColor(.textSecondary)
        }
        .onTapGesture {
            // Every tap does something: tapping the current "before" photo
            // opens its own picker (so it's never a dead tap), tapping any
            // other un-selected photo quick-assigns it as "after" (recent/
            // progress). Tapping the current "after" photo is a no-op — it's
            // already selected.
            if isBefore {
                pickerTarget = .before
            } else if !isAfter {
                afterPhotoId = item.id
            }
        }
    }

    private func slotBadge(_ letter: String, tint: Color) -> some View {
    @ScaledMetric(relativeTo: .caption2) private var slotBadgeSize: CGFloat = 18

        Text(letter)
            .font(.caption2.weight(.heavy))
            .foregroundColor(Color.onAccent)
            .frame(width: slotBadgeSize, height: slotBadgeSize)
            .background(tint)
            .clipShape(Circle())
            .padding(4)
    }
}
