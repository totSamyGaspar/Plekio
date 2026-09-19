//
//  DiaryProgressGalleryView.swift
//  PillFlow
//
//  Created by Edward Gasparian on 24.08.2026.
//
//  The "Progress Gallery" tab: category filter, photo cards, and picking two
//  checkpoints to compare. Split out of DiaryView.
//
//  The category filter is local tab state, but the comparison selection
//  arrives as a binding: the screen header can start a comparison too.
//

import SwiftUI

struct DiaryProgressGalleryView: View {
    let checkpoints: [DiaryPhotoCheckpoint]
    @Binding var selection: [UUID]
    let onInspect: (UUID) -> Void
    let onLaunchComparison: () -> Void
    
    @State private var categoryFilter: String?
    
    private var availableCategories: [String] {
        Array(Set(checkpoints.map(\.category))).sorted()
    }
    
    private var filteredPhotoCheckpoints: [DiaryPhotoCheckpoint] {
        guard let categoryFilter else { return checkpoints }
        return checkpoints.filter { $0.category == categoryFilter }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            categoryFilterBar
            compareHeroCard
            
            if filteredPhotoCheckpoints.isEmpty {
                EmptyStateView(
                    icon: "photo.stack.fill",
                    title: checkpoints.isEmpty ? "No progress photos yet" : "No photos in this category"
                )
            } else {
                // Lazy: a plain VStack here would build and start loading
                // every photo banner up front regardless of scroll position —
                // fine for a handful of photos, but it means a long progress
                // history eagerly decodes dozens of full-size images at once
                // instead of only the ones actually on screen.
                LazyVStack(spacing: 16) {
                    ForEach(Array(filteredPhotoCheckpoints.enumerated()), id: \.element.id) { index, item in
                        photoCheckpointCard(index: index, item: item)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var categoryFilterBar: some View {
        HStack {
            Text("Category:")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.textSecondary)
            Menu {
                Button("All Photos (\(checkpoints.count))") { categoryFilter = nil }
                ForEach(availableCategories, id: \.self) { cat in
                    let count = checkpoints.filter { $0.category == cat }.count
                    Button("\(cat) (\(count))") { categoryFilter = cat }
                }
            } label: {
                HStack {
                    Text(categoryFilter.map { "\($0) (\(filteredPhotoCheckpoints.count))" } ?? "All Photos (\(checkpoints.count))")
                    Image(systemName: "chevron.down")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.textPrimary.opacity(0.8))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.appSurface)
                .cornerRadius(12)
            }
            Spacer()
        }
    }
    
    private var compareHeroCard: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle().fill(Color.accentPrimary.opacity(0.15)).frame(width: 46, height: 46)
                Image(systemName: "arrow.left.arrow.right").foregroundColor(.accentPrimary)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Compare Visual Transformation")
                    .scaledFont(size: 18, relativeTo: .headline, weight: .bold, design: .serif)
                    .foregroundColor(.textPrimary)
                Text(
                    selection.isEmpty
                    ? "Select any two checkpoints to view a side-by-side comparison."
                    : "\(selection.count)/2 checkpoints selected."
                )
                .font(.caption)
                .foregroundColor(.textSecondary)
                
                Button {
                    onLaunchComparison()
                } label: {
                    // ViewThatFits rather than scaling down: when the full label doesn't
                    // fit, show the short one at full size instead of an unreadable
                    // shrunken one. Translators supply their own short variant.
                    ViewThatFits(in: .horizontal) {
                        Text("LAUNCH BEFORE / AFTER COMPARISON")
                        Text("COMPARE PHOTOS")
                        Text("COMPARE")
                    }
                    .font(.caption.weight(.heavy))
                    .lineLimit(1)
                    .foregroundColor(selection.count == 2 ? Color.onAccent : .textTertiary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(selection.count == 2 ? Color.accentPrimary : Color.textPrimary.opacity(0.06))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .disabled(selection.count != 2)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.accentPrimary.opacity(0.2), lineWidth: 1))
    }
    
    private func photoCheckpointCard(index: Int, item: DiaryPhotoCheckpoint) -> some View {
        let isSelected = selection.contains(item.id)
        
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                onInspect(item.id)
            } label: {
                ZStack(alignment: .topLeading) {
                    // Sized by the banner's width, not its height: it stretches
                    // to the full card and is the longer edge.
                    DiaryAsyncPhoto(photoId: item.id, targetPointSize: 400)
                        .frame(height: 180)
                        .frame(maxWidth: .infinity)
                        .clipped()
                    
                    Text(item.category)
                        .font(.caption2.weight(.heavy))
                        .textCase(.uppercase)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.55))
                        .cornerRadius(6)
                        .padding(10)
                }
                .overlay(alignment: .topTrailing) {
                    Text("#\(index + 1)")
                        .font(.caption2.weight(.heavy))
                        .foregroundColor(Color.onAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentPrimary)
                        .clipShape(Capsule())
                        .padding(10)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(item.entry.checkInDate.formatted(date: .numeric, time: .omitted), systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    Spacer()
                    Text("Mood: \(item.entry.moodTitle)")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.accentPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentPrimary.opacity(0.12))
                        .clipShape(Capsule())
                }
                
                let caption = item.entry.displayCaption
                if !caption.isEmpty {
                    Text(caption)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                        .lineLimit(2)
                }
                
                HStack {
                    Button {
                        onInspect(item.id)
                    } label: {
                        Text("Inspect Photo →")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.accentPrimary)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    Spacer(minLength: 12)
                    
                    // A dedicated, plain-styled Button whose whole pill (not just
                    // the text glyphs) is the tap target — .contentShape keeps the
                    // hit-testing region pinned exactly to the visible pill so a
                    // tap here can never register on a neighboring control.
                    Button {
                        toggleComparisonSelection(item.id)
                    } label: {
                        HStack(spacing: 4) {
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.caption2.weight(.heavy))
                            }
                            Text(isSelected ? "Selected" : "Compare")
                                .font(.caption.weight(.bold))
                                .lineLimit(2)
                        }
                        .foregroundColor(isSelected ? Color.onAccent : .textPrimary.opacity(0.7))
                        .padding(.horizontal, 14)
                        .frame(minWidth: 88, minHeight: 44)
                        .background(isSelected ? Color.accentPrimary : Color.appBackground)
                        .cornerRadius(10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
        }
        .background(
            ZStack {
                Color.appSurface
                if isSelected { Color.accentPrimary.opacity(0.08) }
            }
        )
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(isSelected ? Color.accentPrimary : Color.clear, lineWidth: 3))
        .shadow(color: isSelected ? Color.accentPrimary.opacity(0.25) : .clear, radius: 10)
    }
    
    private func toggleComparisonSelection(_ id: UUID) {
        if let idx = selection.firstIndex(of: id) {
            selection.remove(at: idx)
        } else {
            if selection.count >= 2 {
                selection.removeFirst()
            }
            selection.append(id)
        }
    }
}
