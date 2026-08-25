//
//  DiaryView.swift
//  PillFlow
//
//  Created by Edward Gasparian on 24.08.2026.
//
//  The Diary tab's home screen — mirrors the "Daily Health & Mood Diary"
//  reference design 1:1 (hero header, today's check-in card, stats grid, and
//  the Journal Feed / Progress Gallery / Mood & Trends sub-tabs), recolored
//  to PillFlow's dark theme instead of the reference's light palette.
//

import SwiftUI

private enum DiarySubTab: String, CaseIterable, Identifiable {
    case journalFeed, progressGallery, moodTrends

    var id: String { rawValue }

    var title: String {
        switch self {
        case .journalFeed: return "Journal Feed"
        case .progressGallery: return "Progress Gallery"
        case .moodTrends: return "Mood & Trends"
        }
    }

    var icon: String {
        switch self {
        case .journalFeed: return "doc.text.fill"
        case .progressGallery: return "photo.stack.fill"
        case .moodTrends: return "chart.line.uptrend.xyaxis"
        }
    }
}

/// One progress photo, paired with the entry it came from — Progress Gallery
/// treats each photo as its own "checkpoint", not each diary entry.
private struct DiaryPhotoCheckpoint: Identifiable {
    let id: UUID // the photo's id
    let category: String
    let entry: DiaryEntry
}

/// Fully-resolved before/after pair handed to the comparison sheet.
/// Built synchronously in one step (rather than toggling a Bool flag and
/// separately recomputing "the current selection" inside the sheet's content
/// closure) so `.sheet(item:)` always has a complete, valid pair the instant
/// it's asked to present — no window where the sheet appears before its
/// dependent @State has finished propagating, which was leaving the sheet
/// blank when opened straight from the "Compare Progress" header button.
private struct DiaryComparisonPayload: Identifiable {
    let id = UUID()
    let beforeId: UUID
    let afterId: UUID
}

struct DiaryView<VM: DiaryViewModelProtocol>: View {
    @StateObject private var viewModel: VM

    @State private var showingCheckIn = false
    @State private var entryBeingEdited: DiaryEntry?
    @State private var showingDeleteAlert = false
    @State private var entryToDelete: DiaryEntry?

    @State private var selectedSubTab: DiarySubTab = .journalFeed

    // Journal Feed filters
    @State private var searchText = ""
    @State private var moodFilter: DiaryMood?
    @State private var photosOnlyFilter = false

    // Progress Gallery
    @State private var categoryFilter: String?
    @State private var comparisonSelection: [UUID] = []
    @State private var comparisonPayload: DiaryComparisonPayload?
    @State private var inspectingPhotoId: UUID?

    private let quickMoods: [(label: String, emoji: String, mood: DiaryMood)] = [
        ("Great", "☀️", .great),
        ("Good", "🙂", .good),
        ("Okay", "😊", .neutral),
        ("Tired", "😴", .exhausted),
    ]

    init(viewModel: @autoclosure @escaping () -> VM) {
        self._viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        ZStack {
            Color.bgDark.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerSection
                    todaySection
                    statsGrid
                    subTabBar
                    content
                }
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingCheckIn) {
            DiaryCheckInView()
                .preferredColorScheme(.dark)
        }
        .sheet(item: $entryBeingEdited) { entry in
            DiaryCheckInView(editingEntry: entry)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: Binding(
            get: { inspectingPhotoId != nil },
            set: { if !$0 { inspectingPhotoId = nil } }
        )) {
            if let id = inspectingPhotoId {
                PhotoZoomView(photoId: id)
            }
        }
        .sheet(item: $comparisonPayload) { payload in
            BeforeAfterComparisonView(
                checkpoints: allPhotoCheckpoints,
                beforePhotoId: payload.beforeId,
                afterPhotoId: payload.afterId
            )
            .preferredColorScheme(.dark)
        }
        .alert("Delete Check-in?", isPresented: $showingDeleteAlert, presenting: entryToDelete) { entry in
            Button("Delete", role: .destructive) {
                viewModel.deleteEntry(entry)
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This diary entry and its photos will be permanently removed.")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("WELLNESS DIARY & PROGRESS LOG")
                    .font(.caption2.weight(.heavy))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.cardDark)
                    .clipShape(Capsule())
                Spacer()
                Text("· \(Date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
            }

            Text("Daily Health & Mood Diary")
                .font(.system(size: 30, weight: .heavy, design: .serif))
                .foregroundColor(.white)

            Text("Track how your body responds to your regimen, log symptoms, record daily energy levels, and compare progress photos over time.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))

            HStack(spacing: 12) {
                Button {
                    openComparison()
                } label: {
                    Label("Compare Progress", systemImage: "arrow.triangle.2.circlepath")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.cardDark)
                        .cornerRadius(14)
                }
                .buttonStyle(.plain)

                Button {
                    showingCheckIn = true
                } label: {
                    Label("Add New Entry", systemImage: "plus")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(Color.bgDark)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Color.neonMint)
                        .cornerRadius(14)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Today's check-in card

    private var todaySection: some View {
        Group {
            if let entry = viewModel.todaysEntry {
                loggedTodayCard(entry)
            } else {
                pendingTodayCard
            }
        }
        .padding(.horizontal)
    }

    private var pendingTodayCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").foregroundColor(.yellow)
                Text("TODAY'S WELLNESS CHECK-IN IS PENDING")
                    .font(.caption.weight(.heavy))
                    .foregroundColor(.white.opacity(0.7))
            }
            Text("How are you feeling right now? Tap a mood to log quickly or fill in detailed notes & photos.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.5))

            HStack(spacing: 10) {
                ForEach(quickMoods, id: \.label) { item in
                    Button {
                        withAnimation { viewModel.quickLog(mood: item.mood) }
                    } label: {
                        VStack(spacing: 4) {
                            Text(item.emoji)
                            Text(item.label)
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundColor(.white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.bgDark)
                        .cornerRadius(14)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .background(Color.cardDark)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.neonMint.opacity(0.2), lineWidth: 1))
    }

    private func loggedTodayCard(_ entry: DiaryEntry) -> some View {
        let mood = DiaryMood(rawValue: entry.moodLabel)
        let quote = entry.physicalSummary.isEmpty ? entry.reflectionNotes : entry.physicalSummary

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TODAY'S CHECK-IN LOGGED")
                    .font(.caption2.weight(.heavy))
                    .foregroundColor(.neonMint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.neonMint.opacity(0.12))
                    .clipShape(Capsule())
                Spacer()
                Text("at \(entry.checkInDate.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
            }

            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle().fill(Color.neonMint.opacity(0.15)).frame(width: 40, height: 40)
                    Text(mood?.emoji ?? "📝").font(.title3)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(todaySummaryLine(entry))
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white)
                    if !quote.isEmpty {
                        Text("“\(quote)”")
                            .font(.subheadline)
                            .italic()
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(2)
                    }
                }
            }

            HStack {
                Spacer()
                Button {
                    entryBeingEdited = entry
                } label: {
                    Label("Edit Entry", systemImage: "pencil")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(Color.cardDark)
        .cornerRadius(20)
    }

    private func todaySummaryLine(_ entry: DiaryEntry) -> String {
        // Quick-logged entries never captured a real energyLevel — it's just
        // DiaryEntryDraft's static default — so showing "Energy: 4/5" here
        // would present a fabricated number as if the user reported it.
        var parts = entry.isQuickLog
            ? ["Mood: \(entry.moodLabel)", "Quick log"]
            : ["Mood: \(entry.moodLabel)", "Energy: \(entry.energyLevel)/5"]
        if !entry.photoIds.isEmpty {
            parts.append("\(entry.photoIds.count) Photo\(entry.photoIds.count == 1 ? "" : "s") attached")
        }
        return parts.joined(separator: " • ")
    }

    // MARK: - Stats grid

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            statCard(title: "7-DAY AVG MOOD", value: String(format: "%.1f /5", viewModel.avgMoodScore), icon: "sun.max.fill", iconColor: .yellow)
            statCard(title: "AVG ENERGY", value: String(format: "%.1f /5", viewModel.avgEnergyLevel), icon: "bolt.fill", iconColor: .neonMint)
            statCard(title: "PROGRESS PHOTOS", value: "\(viewModel.totalPhotosLogged) logged", icon: "camera.fill", iconColor: .white.opacity(0.6))
            statCard(title: "SLEEP AVERAGE", value: String(format: "%.1f hrs", viewModel.avgSleepHours), icon: "moon.fill", iconColor: .purple)
        }
        .padding(.horizontal)
    }

    private func statCard(title: String, value: String, icon: String, iconColor: Color) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption2.weight(.heavy))
                    .foregroundColor(.white.opacity(0.4))
                Text(value)
                    .font(.title3.weight(.bold))
                    .foregroundColor(.white)
            }
            Spacer()
            Image(systemName: icon)
                .foregroundColor(iconColor)
        }
        .padding(16)
        .background(Color.cardDark)
        .cornerRadius(16)
    }

    // MARK: - Sub-tab bar

    private var subTabBar: some View {
        HStack(spacing: 6) {
            ForEach(DiarySubTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedSubTab = tab }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon).font(.caption)
                        Text(tab.title).font(.caption.weight(.bold))
                        if let count = subTabCount(tab) {
                            Text("(\(count))")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                    .foregroundColor(selectedSubTab == tab ? .neonMint : .white.opacity(0.5))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(selectedSubTab == tab ? Color.cardDark : Color.clear)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .cornerRadius(14)
        .padding(.horizontal)
    }

    private func subTabCount(_ tab: DiarySubTab) -> Int? {
        switch tab {
        case .journalFeed: return viewModel.entries.count
        case .progressGallery: return allPhotoCheckpoints.count
        case .moodTrends: return nil
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch selectedSubTab {
        case .journalFeed:
            journalFeedTab
        case .progressGallery:
            progressGalleryTab
        case .moodTrends:
            moodTrendsTab
        }
    }

    // MARK: - Journal Feed

    private var journalFeedTab: some View {
        VStack(spacing: 16) {
            searchFilterBar

            if filteredEntries.isEmpty {
                emptyStateView(
                    icon: "text.book.closed.fill",
                    title: viewModel.entries.isEmpty ? "No check-ins yet" : "No entries match your filters"
                )
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(filteredEntries) { entry in
                        DiaryEntryRowView(
                            entry: entry,
                            onEdit: { entryBeingEdited = entry },
                            onDelete: {
                                entryToDelete = entry
                                showingDeleteAlert = true
                            }
                        )
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private var filteredEntries: [DiaryEntry] {
        viewModel.entries.filter { entry in
            let matchesSearch = searchText.isEmpty
                || entry.physicalSummary.localizedCaseInsensitiveContains(searchText)
                || entry.reflectionNotes.localizedCaseInsensitiveContains(searchText)
            let matchesMood = moodFilter == nil || entry.moodLabel == moodFilter?.rawValue
            let matchesPhotos = !photosOnlyFilter || !entry.photoIds.isEmpty
            return matchesSearch && matchesMood && matchesPhotos
        }
    }

    private var searchFilterBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.4))
                TextField("Search notes", text: $searchText)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.cardDark)
            .cornerRadius(12)

            HStack(spacing: 10) {
                Menu {
                    Button("All Moods") { moodFilter = nil }
                    ForEach(DiaryMood.allCases) { mood in
                        Button("\(mood.emoji) \(mood.rawValue)") { moodFilter = mood }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(moodFilter?.rawValue ?? "All Moods")
                        Image(systemName: "chevron.down")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.cardDark)
                    .cornerRadius(10)
                }

                Button {
                    photosOnlyFilter.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                        Text("With Photos")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(photosOnlyFilter ? Color.bgDark : .white.opacity(0.7))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(photosOnlyFilter ? Color.neonMint : Color.cardDark)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
    }

    private func emptyStateView(icon: String, title: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundColor(.white.opacity(0.2))
            Text(title)
                .font(.headline)
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    // MARK: - Progress Gallery

    /// Every photo across every entry, flattened into individual checkpoints,
    /// newest first (entries are already sorted newest-first).
    private var allPhotoCheckpoints: [DiaryPhotoCheckpoint] {
        viewModel.entries.flatMap { entry in
            entry.photoIds.map { photoId in
                DiaryPhotoCheckpoint(id: photoId, category: category(for: entry), entry: entry)
            }
        }
    }

    private func category(for entry: DiaryEntry) -> String {
        if let tag = entry.milestoneTags.first {
            return tag.uppercased().replacingOccurrences(of: " ", with: "_")
        }
        return "DIARY_PHOTO"
    }

    private var availableCategories: [String] {
        Array(Set(allPhotoCheckpoints.map(\.category))).sorted()
    }

    private var filteredPhotoCheckpoints: [DiaryPhotoCheckpoint] {
        guard let categoryFilter else { return allPhotoCheckpoints }
        return allPhotoCheckpoints.filter { $0.category == categoryFilter }
    }

    private var progressGalleryTab: some View {
        VStack(spacing: 16) {
            categoryFilterBar
            compareHeroCard

            if filteredPhotoCheckpoints.isEmpty {
                emptyStateView(
                    icon: "photo.stack.fill",
                    title: allPhotoCheckpoints.isEmpty ? "No progress photos yet" : "No photos in this category"
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
                .foregroundColor(.white.opacity(0.6))
            Menu {
                Button("All Photos (\(allPhotoCheckpoints.count))") { categoryFilter = nil }
                ForEach(availableCategories, id: \.self) { cat in
                    let count = allPhotoCheckpoints.filter { $0.category == cat }.count
                    Button("\(cat) (\(count))") { categoryFilter = cat }
                }
            } label: {
                HStack {
                    Text(categoryFilter.map { "\($0) (\(filteredPhotoCheckpoints.count))" } ?? "All Photos (\(allPhotoCheckpoints.count))")
                    Image(systemName: "chevron.down")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.cardDark)
                .cornerRadius(12)
            }
            Spacer()
        }
    }

    private var compareHeroCard: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle().fill(Color.neonMint.opacity(0.15)).frame(width: 46, height: 46)
                Image(systemName: "arrow.left.arrow.right").foregroundColor(.neonMint)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Compare Visual Transformation")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                Text(
                    comparisonSelection.isEmpty
                        ? "Select any two checkpoints to view a side-by-side comparison."
                        : "\(comparisonSelection.count)/2 checkpoints selected."
                )
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))

                Button {
                    openComparison()
                } label: {
                    Text("LAUNCH BEFORE / AFTER COMPARISON")
                        .font(.caption.weight(.heavy))
                        .foregroundColor(comparisonSelection.count == 2 ? Color.bgDark : .white.opacity(0.35))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(comparisonSelection.count == 2 ? Color.neonMint : Color.white.opacity(0.06))
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .disabled(comparisonSelection.count != 2)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardDark)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.neonMint.opacity(0.2), lineWidth: 1))
    }

    private func photoCheckpointCard(index: Int, item: DiaryPhotoCheckpoint) -> some View {
        let isSelected = comparisonSelection.contains(item.id)

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                inspectingPhotoId = item.id
            } label: {
                ZStack(alignment: .topLeading) {
                    DiaryAsyncPhoto(photoId: item.id)
                        .frame(height: 180)
                        .frame(maxWidth: .infinity)
                        .clipped()

                    Text(item.category)
                        .font(.caption2.weight(.heavy))
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
                        .foregroundColor(Color.bgDark)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.neonMint)
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
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                    Text("Mood: \(item.entry.moodLabel)")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.neonMint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.neonMint.opacity(0.12))
                        .clipShape(Capsule())
                }

                let caption = item.entry.reflectionNotes.isEmpty ? item.entry.physicalSummary : item.entry.reflectionNotes
                if !caption.isEmpty {
                    Text(caption)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(2)
                }

                HStack {
                    Button {
                        inspectingPhotoId = item.id
                    } label: {
                        Text("Inspect Photo →")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.neonMint)
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
                        }
                        .foregroundColor(isSelected ? Color.bgDark : .white.opacity(0.7))
                        .padding(.horizontal, 14)
                        .frame(minWidth: 88, minHeight: 44)
                        .background(isSelected ? Color.neonMint : Color.bgDark)
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
                Color.cardDark
                if isSelected { Color.neonMint.opacity(0.08) }
            }
        )
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(isSelected ? Color.neonMint : Color.clear, lineWidth: 3))
        .shadow(color: isSelected ? Color.neonMint.opacity(0.25) : .clear, radius: 10)
    }

    /// Opens the Before/After comparison sheet directly, from either the
    /// header's "Compare Progress" button or a gallery card's own launch
    /// button. If two checkpoints aren't already picked (e.g. the user hasn't
    /// selected any via the gallery's per-card "Compare" toggles), default to
    /// the earliest vs. the most recent photo — earlier baseline vs. latest
    /// progress — which the picker dropdowns inside the sheet can then swap.
    private func openComparison() {
        if comparisonSelection.count == 2 {
            let sorted = sortedComparisonCheckpoints
            guard sorted.count == 2 else { return }
            comparisonPayload = DiaryComparisonPayload(beforeId: sorted[0].id, afterId: sorted[1].id)
            return
        }

        let sorted = allPhotoCheckpoints.sorted { $0.entry.checkInDate < $1.entry.checkInDate }
        guard sorted.count >= 2 else {
            withAnimation { selectedSubTab = .progressGallery }
            return
        }
        comparisonPayload = DiaryComparisonPayload(beforeId: sorted.first!.id, afterId: sorted.last!.id)
    }

    private func toggleComparisonSelection(_ id: UUID) {
        if let idx = comparisonSelection.firstIndex(of: id) {
            comparisonSelection.remove(at: idx)
        } else {
            if comparisonSelection.count >= 2 {
                comparisonSelection.removeFirst()
            }
            comparisonSelection.append(id)
        }
    }

    private var sortedComparisonCheckpoints: [DiaryPhotoCheckpoint] {
        comparisonSelection
            .compactMap { id in allPhotoCheckpoints.first { $0.id == id } }
            .sorted { $0.entry.checkInDate < $1.entry.checkInDate }
    }

    // MARK: - Mood & Trends

    /// Most recent entries, oldest first, so the chart reads left-to-right chronologically.
    private var moodChartEntries: [DiaryEntry] {
        Array(viewModel.entries.prefix(7)).sorted { $0.checkInDate < $1.checkInDate }
    }

    private var moodTrendsTab: some View {
        VStack(spacing: 16) {
            moodProgressionCard
            physicalEnergyCard
        }
        .padding(.horizontal)
    }

    private var moodProgressionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Mood & Well-being Progression")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                Text("Daily reported emotional and physical state")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }

            if moodChartEntries.isEmpty {
                Text("Log a few check-ins to see your mood trend here.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else {
                HStack(alignment: .bottom, spacing: 14) {
                    ForEach(moodChartEntries) { entry in
                        moodBar(entry)
                    }
                }
            }

            HStack(spacing: 8) {
                Text(moodBaselineLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.bgDark)
                    .clipShape(Capsule())

                Text(adherenceInsightLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.neonMint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.neonMint.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(18)
        .background(Color.cardDark)
        .cornerRadius(20)
    }

    /// Fixed bar width (matches WeeklyAdherenceView's per-bar sizing) — kept
    /// constant regardless of entry count so a chart with only 1-2 entries
    /// doesn't stretch its bars into wide, flattened domes.
    private let moodBarWidth: CGFloat = 40

    private func moodBar(_ entry: DiaryEntry) -> some View {
        let mood = DiaryMood(rawValue: entry.moodLabel)
        let heightFraction = CGFloat(entry.moodScore) / 5.0

        return VStack(spacing: 8) {
            ZStack(alignment: .bottom) {
                TopRoundedBar()
                    .fill(Color.white.opacity(0.06))
                TopRoundedBar()
                    .fill(Color.neonMint)
                    .frame(height: max(16, 80 * heightFraction))
                    .shadow(color: Color.neonMint.opacity(0.3), radius: 5, x: 0, y: -5)
                    .overlay(alignment: .top) {
                        Text(mood?.emoji ?? "🙂")
                            .font(.caption2)
                            .padding(4)
                            .background(Circle().fill(Color.cardDark))
                            .offset(y: -10)
                    }
            }
            .frame(width: moodBarWidth, height: 80)

            Text(entry.checkInDate.formatted(.dateTime.weekday(.abbreviated)))
                .font(.caption2.weight(.bold))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(width: moodBarWidth)
    }

    private var moodBaselineLabel: String {
        guard moodChartEntries.count >= 2 else { return "Baseline: Not Enough Data" }
        let half = moodChartEntries.count / 2
        let firstHalf = moodChartEntries.prefix(half)
        let secondHalf = moodChartEntries.suffix(half)
        let firstAvg = Double(firstHalf.reduce(0) { $0 + $1.moodScore }) / Double(firstHalf.count)
        let secondAvg = Double(secondHalf.reduce(0) { $0 + $1.moodScore }) / Double(secondHalf.count)
        let delta = secondAvg - firstAvg
        if delta > 0.4 { return "Baseline: Improving" }
        if delta < -0.4 { return "Baseline: Declining" }
        return "Baseline: Stable Mood"
    }

    private var adherenceInsightLabel: String {
        viewModel.avgMoodScore >= 3.5 ? "Adherence Positively Correlated" : "Keep Logging To See Trends"
    }

    private var physicalEnergyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Physical Energy & Rest")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                Text("Impact of sleep hours on daytime vitality")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }

            metricBar(
                icon: "moon.fill", iconColor: .purple,
                title: "Average Sleep Quality",
                valueText: String(format: "%.1f hrs / night", viewModel.avgSleepHours),
                progress: min(viewModel.avgSleepHours / 9.0, 1.0),
                tint: .purple
            )

            metricBar(
                icon: "bolt.fill", iconColor: .orange,
                title: "Daytime Energy Baseline",
                valueText: String(format: "%.1f / 5", viewModel.avgEnergyLevel),
                progress: min(viewModel.avgEnergyLevel / 5.0, 1.0),
                tint: .orange
            )

            Text("Taking Magnesium consistently before sleep contributes to higher morning energy scores.")
                .font(.caption)
                .italic()
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(18)
        .background(Color.cardDark)
        .cornerRadius(20)
    }

    private func metricBar(icon: String, iconColor: Color, title: String, valueText: String, progress: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: icon).foregroundColor(iconColor)
                    Text(title).foregroundColor(.white.opacity(0.8))
                }
                .font(.subheadline.weight(.semibold))
                Spacer()
                Text(valueText)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(tint)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 6).fill(tint).frame(width: max(4, geo.size.width * progress))
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Full-screen photo zoom

private struct PhotoZoomView: View {
    let photoId: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView().tint(.white)
            }

            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
                Spacer()
            }
            .padding()
        }
        .onAppear {
            ImageCache.shared.loadAsync(for: photoId) { self.image = $0 }
        }
    }
}

// MARK: - Before / After comparison

private struct BeforeAfterComparisonView: View {
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

    private static let isoDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init(checkpoints: [DiaryPhotoCheckpoint], beforePhotoId: UUID, afterPhotoId: UUID) {
        self.checkpoints = checkpoints
        self._beforePhotoId = State(initialValue: beforePhotoId)
        self._afterPhotoId = State(initialValue: afterPhotoId)
    }

    private var beforeCheckpoint: DiaryPhotoCheckpoint? { checkpoints.first { $0.id == beforePhotoId } }
    private var afterCheckpoint: DiaryPhotoCheckpoint? { checkpoints.first { $0.id == afterPhotoId } }

    var body: some View {
        ZStack {
            Color.bgDark.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    header

                    photoSelectorRow(label: "BEFORE PHOTO (A):", tint: .neonMint, checkpoint: beforeCheckpoint) {
                        pickerTarget = .before
                    }
                    photoSelectorRow(label: "AFTER PHOTO (B):", tint: .orange, checkpoint: afterCheckpoint) {
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
        .onAppear { loadImages() }
        .onChange(of: beforePhotoId) { _, _ in loadImages() }
        .onChange(of: afterPhotoId) { _, _ in loadImages() }
        .sheet(item: $pickerTarget) { slot in
            photoPickerSheet(for: slot)
        }
    }

    private func loadImages() {
        ImageCache.shared.loadAsync(for: beforePhotoId) { beforeImage = $0 }
        ImageCache.shared.loadAsync(for: afterPhotoId) { afterImage = $0 }
    }

    // MARK: Header + mode toggle

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(Color.neonMint.opacity(0.15)).frame(width: 40, height: 40)
                Image(systemName: "arrow.left.arrow.right")
                    .font(.subheadline)
                    .foregroundColor(.neonMint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Visual Progress Comparison")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                Text("Track your recovery, skin changes & wellness transformation")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.55))
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 8) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(7)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                modeToggle
            }
        }
    }

    private var modeToggle: some View {
        HStack(spacing: 4) {
            modeButton("Side by\nSide", isActive: mode == .sideBySide) { mode = .sideBySide }
            modeButton("Split\nSlider", isActive: mode == .splitSlider) { mode = .splitSlider }
        }
    }

    private func modeButton(_ title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption2.weight(.bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundColor(isActive ? Color.bgDark : .white.opacity(0.6))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(minWidth: 56)
                .background(isActive ? Color.neonMint : Color.white.opacity(0.06))
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    // MARK: Photo selector rows + picker sheet

    private func photoSelectorRow(label: String, tint: Color, checkpoint: DiaryPhotoCheckpoint?, action: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.caption2.weight(.heavy))
                .foregroundColor(tint)
                .frame(width: 96, alignment: .leading)

            Button(action: action) {
                HStack {
                    Text(captionText(for: checkpoint))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 6)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.cardDark)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
    }

    private func captionText(for checkpoint: DiaryPhotoCheckpoint?) -> String {
        guard let checkpoint else { return "Select a photo" }
        let dateText = Self.isoDateFormatter.string(from: checkpoint.entry.checkInDate)
        let notes = checkpoint.entry.reflectionNotes.isEmpty ? checkpoint.entry.physicalSummary : checkpoint.entry.reflectionNotes
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
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                            .foregroundColor(.neonMint)
                    }
                }
                .listRowBackground(Color.cardDark)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.bgDark)
            .navigationTitle(slot == .before ? "Select Before Photo" : "Select After Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { pickerTarget = nil }
                }
            }
        }
        .preferredColorScheme(.dark)
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
                        Color.white.opacity(0.05)
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
                            tag("BEFORE (\(shortDate(beforeCheckpoint)))", tint: .neonMint)
                            Spacer()
                            tag("AFTER (\(shortDate(afterCheckpoint)))", tint: .orange)
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
                    .foregroundColor(.neonMint)
                Slider(value: $sliderPosition)
                    .tint(.white)
                Text("After")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.orange)
            }
        }
    }

    private func tag(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.heavy))
            .foregroundColor(Color.bgDark)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint)
            .clipShape(Capsule())
    }

    private func shortDate(_ checkpoint: DiaryPhotoCheckpoint?) -> String {
        guard let checkpoint else { return "--" }
        return Self.isoDateFormatter.string(from: checkpoint.entry.checkInDate)
    }

    // MARK: Side by side mode

    private var sideBySideView: some View {
        VStack(spacing: 16) {
            stateCard(title: "STATE A (EARLIER BASELINE)", tint: .neonMint, checkpoint: beforeCheckpoint, image: beforeImage)
            stateCard(title: "STATE B (RECENT / PROGRESS)", tint: .orange, checkpoint: afterCheckpoint, image: afterImage)
        }
    }

    private func stateCard(title: String, tint: Color, checkpoint: DiaryPhotoCheckpoint?, image: UIImage?) -> some View {
        let boldLine = checkpoint?.entry.milestoneTags.first ?? checkpoint?.entry.physicalSummary ?? ""
        let quote = checkpoint.map { $0.entry.physicalSummary.isEmpty ? $0.entry.reflectionNotes : $0.entry.physicalSummary } ?? ""

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.caption2.weight(.heavy))
                    .foregroundColor(Color.bgDark)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(tint)
                    .clipShape(Capsule())
                Spacer()
                Text(shortDate(checkpoint))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }

            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.white.opacity(0.05)
                }
            }
            .frame(height: 220)
            .frame(maxWidth: .infinity)
            .clipped()
            .cornerRadius(14)

            if !boldLine.isEmpty {
                Text(boldLine)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.9))
            }
            if !quote.isEmpty && quote != boldLine {
                Text(quote)
                    .font(.caption.italic())
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(2)
            }
            if let checkpoint {
                Text("Mood: \(checkpoint.entry.moodLabel)")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(tint)
            }
        }
        .padding(14)
        .background(Color.cardDark)
        .cornerRadius(18)
    }

    // MARK: Available photos strip

    private var availablePhotosSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AVAILABLE PROGRESS PHOTOS (\(checkpoints.count))")
                .font(.caption2.weight(.heavy))
                .foregroundColor(.white.opacity(0.4))
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
                    if isBefore { slotBadge("A", tint: .neonMint) }
                }
                .overlay(alignment: .topTrailing) {
                    if isAfter { slotBadge("B", tint: .orange) }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke((isBefore || isAfter) ? Color.neonMint.opacity(0.8) : Color.clear, lineWidth: 2)
                )

            Text(Self.isoDateFormatter.string(from: item.entry.checkInDate))
                .font(.caption2)
                .foregroundColor(.white.opacity(0.4))
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
        Text(letter)
            .font(.caption2.weight(.heavy))
            .foregroundColor(Color.bgDark)
            .frame(width: 18, height: 18)
            .background(tint)
            .clipShape(Circle())
            .padding(4)
    }
}

extension DiaryView where VM == DiaryViewModel {
    init() {
        self.init(viewModel: DIContainer.shared.resolve((any DiaryViewModelProtocol).self) as! VM)
    }
}

#Preview {
    NavigationStack {
        DiaryView(viewModel: MockDiaryViewModel())
            .preferredColorScheme(.dark)
    }
}
