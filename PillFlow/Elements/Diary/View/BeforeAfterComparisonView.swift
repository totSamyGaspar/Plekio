//
//  BeforeAfterComparisonView.swift
//  PillFlow
//
//  Created by Edward Gasparian on 24.08.2026.
//
//  Before/after comparison: two modes (split slider and side by side),
//  checkpoint pickers, and a strip of every available photo.
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
                    
                    ComparisonSlotRow(label: "BEFORE PHOTO (A):", tint: .accentPrimary, checkpoint: beforeCheckpoint) {
                        pickerTarget = .before
                    }
                    ComparisonSlotRow(label: "AFTER PHOTO (B):", tint: .warmAccent, checkpoint: afterCheckpoint) {
                        pickerTarget = .after
                    }
                    
                    switch mode {
                    case .splitSlider: splitSliderView
                    case .sideBySide: sideBySideView
                    }
                    
                    ComparisonPhotoStrip(
                        checkpoints: checkpoints,
                        beforePhotoId: beforePhotoId,
                        afterPhotoId: afterPhotoId,
                        onOpenBeforePicker: { pickerTarget = .before },
                        onSelectAfter: { afterPhotoId = $0 }
                    )
                }
                .padding(.horizontal)
                .padding(.vertical)
            }
        }
        // `.task(id:)` restarts itself when the id changes, which replaces an
        // onAppear plus two onChange handlers.
        // Screen-width panes, not the camera's resolution: this sheet holds two
        // photos at once, and decoding both at full size costs tens of megabytes.
        .task(id: beforePhotoId) {
            beforeImage = await ImageCache.shared.image(for: beforePhotoId, targetPointSize: 430)
        }
        .task(id: afterPhotoId) {
            afterImage = await ImageCache.shared.image(for: afterPhotoId, targetPointSize: 430)
        }
        .sheet(item: $pickerTarget) { slot in
            photoPickerSheet(for: slot)
        }
    }
    
    // MARK: Header + mode toggle
    
    /// Title row first, mode toggle on its own row underneath.
    ///
    /// Kept on separate rows: Close expands its touch target by ten points in
    /// every direction, so sharing a trailing column with the mode buttons puts
    /// its hit area over theirs and a tap meant for "Side by Side" shuts the
    /// screen. Stacking them also leaves the title about a
    /// third of the row, which is why it read "Visual Progress C…".
    private var header: some View {
        VStack(spacing: 14) {
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
                // Grows downward instead of truncating when a translation is longer
                // than the row — the failure this header was already showing.
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                closeButton
            }
            
            modeToggle
        }
    }
    
    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.caption)
                .foregroundColor(.textPrimary.opacity(0.7))
                .padding(8)
                .background(Color.textPrimary.opacity(0.08))
                .clipShape(Circle())
        }
        .expandTouchTarget(10)
        .accessibilityLabel("Close")
    }
    
    /// Full width, so the two halves read as one segmented control and each is a
    /// comfortable target. It also stops the labels wrapping in the languages
    /// that need the room — German and Ukrainian.
    private var modeToggle: some View {
        HStack(spacing: 8) {
            // No line break baked into the string: it would land in the wrong
            // place in another language. lineLimit(2) wraps it instead.
            modeButton("Side by Side", isActive: mode == .sideBySide) { mode = .sideBySide }
            modeButton("Split Slider", isActive: mode == .splitSlider) { mode = .splitSlider }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
    
    private func modeButton(_ title: LocalizedStringKey, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption2.weight(.bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundColor(isActive ? Color.onAccent : .textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 40, maxHeight: .infinity)
                .background(isActive ? Color.accentPrimary : Color.textPrimary.opacity(0.06))
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
    
    // MARK: Photo selector rows + picker sheet
    
    /// Which photo the given slot currently holds.
    private func selectedId(for slot: ComparisonSlot) -> UUID {
        switch slot {
        case .before: beforePhotoId
        case .after: afterPhotoId
        }
    }
    
    private func select(_ id: UUID, for slot: ComparisonSlot) {
        switch slot {
        case .before: beforePhotoId = id
        case .after: afterPhotoId = id
        }
        pickerTarget = nil
    }
    
    private func pickerTitle(for slot: ComparisonSlot) -> LocalizedStringKey {
        switch slot {
        case .before: "Select Before Photo"
        case .after: "Select After Photo"
        }
    }
    
    private func photoPickerSheet(for slot: ComparisonSlot) -> some View {
        // Anything that picks between two values by slot is a `switch` in a
        // helper above, never a ternary written inline here: a nested ternary
        // comparing two UUIDs inside a List row builder is one expression the
        // type checker gives up on. So the row below
        // stays a plain expression.
        let chosenId = selectedId(for: slot)
        
        return NavigationStack {
            List(checkpoints) { item in
                let isSelected = item.id == chosenId
                Button {
                    select(item.id, for: slot)
                } label: {
                    HStack {
                        Text(DiaryPhotoCheckpoint.caption(for: item))
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
            .navigationTitle(pickerTitle(for: slot))
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
        return checkpoint.entry.checkInDate.formatted(DiaryPhotoCheckpoint.comparisonDateStyle)
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
}
