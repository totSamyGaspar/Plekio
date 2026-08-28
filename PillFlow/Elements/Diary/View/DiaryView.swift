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

/// A photo opened full-screen. The wrapper exists so this can present via
/// `.sheet(item:)` rather than `.sheet(isPresented:)` with a derived Binding
/// and an `if let` inside — the pattern that already proved unreliable for
/// the comparison sheet (see DiaryComparisonPayload below).
private struct DiaryPhotoInspection: Identifiable {
    /// The photo's id doubles as the presentation id.
    let id: UUID
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

    // Feed filters and the gallery category live inside the tabs themselves;
    // only state shared by the header, the tabs and the sheets stays here.
    @State private var comparisonSelection: [UUID] = []
    @State private var comparisonPayload: DiaryComparisonPayload?
    @State private var inspectingPhoto: DiaryPhotoInspection?

    /// The chip labels differ from the DiaryMood titles ("Okay" rather than
    /// "Neutral"), so they are held separately — still localizable.
    private let quickMoods: [(label: LocalizedStringResource, emoji: String, mood: DiaryMood)] = [
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
            Color.appBackground.ignoresSafeArea()

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
                .appTheme()
        }
        .sheet(item: $entryBeingEdited) { entry in
            DiaryCheckInView(editingEntry: entry)
                .appTheme()
        }
        .sheet(item: $inspectingPhoto) { photo in
            PhotoZoomView(photoId: photo.id)
        }
        .sheet(item: $comparisonPayload) { payload in
            BeforeAfterComparisonView(
                checkpoints: viewModel.photoCheckpoints,
                beforePhotoId: payload.beforeId,
                afterPhotoId: payload.afterId
            )
            .appTheme()
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
                    .foregroundColor(.textPrimary.opacity(0.6))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.appSurface)
                    .clipShape(Capsule())
                Spacer()
                Text("· \(Date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))")
                    .font(.caption)
                    .foregroundColor(.textPrimary.opacity(0.4))
            }

            Text("Daily Health & Mood Diary")
                .font(.system(size: 30, weight: .heavy, design: .serif))
                .foregroundColor(.textPrimary)

            Text("Track how your body responds to your regimen, log symptoms, record daily energy levels, and compare progress photos over time.")
                .font(.subheadline)
                .foregroundColor(.textPrimary.opacity(0.6))

            HStack(spacing: 12) {
                Button {
                    openComparison()
                } label: {
                    Label("Compare Progress", systemImage: "arrow.triangle.2.circlepath")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.textPrimary.opacity(0.8))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.appSurface)
                        .cornerRadius(14)
                }
                .buttonStyle(.plain)

                Button {
                    showingCheckIn = true
                } label: {
                    Label("Add New Entry", systemImage: "plus")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(Color.onAccent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Color.accentPrimary)
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
                    .foregroundColor(.textPrimary.opacity(0.7))
            }
            Text("How are you feeling right now? Tap a mood to log quickly or fill in detailed notes & photos.")
                .font(.subheadline)
                .foregroundColor(.textPrimary.opacity(0.5))

            HStack(spacing: 10) {
                ForEach(quickMoods, id: \.mood) { item in
                    Button {
                        withAnimation { viewModel.quickLog(mood: item.mood) }
                    } label: {
                        VStack(spacing: 4) {
                            Text(verbatim: item.emoji)
                            Text(item.label)
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundColor(.textPrimary.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.appBackground)
                        .cornerRadius(14)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .background(Color.appSurface)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.accentPrimary.opacity(0.2), lineWidth: 1))
    }

    private func loggedTodayCard(_ entry: DiaryEntry) -> some View {
        let mood = DiaryMood(rawValue: entry.moodLabel)
        let quote = entry.displayCaption

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TODAY'S CHECK-IN LOGGED")
                    .font(.caption2.weight(.heavy))
                    .foregroundColor(.accentPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentPrimary.opacity(0.12))
                    .clipShape(Capsule())
                Spacer()
                Text("at \(entry.checkInDate.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.textPrimary.opacity(0.4))
            }

            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle().fill(Color.accentPrimary.opacity(0.15)).frame(width: 40, height: 40)
                    Text(mood?.emoji ?? "📝").font(.title3)
                }
                VStack(alignment: .leading, spacing: 6) {
                    todaySummaryLine(entry)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.textPrimary)
                    if !quote.isEmpty {
                        Text("“\(quote)”")
                            .font(.subheadline)
                            .italic()
                            .foregroundColor(.textPrimary.opacity(0.6))
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
                        .foregroundColor(.textPrimary.opacity(0.8))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .overlay(Capsule().stroke(Color.textPrimary.opacity(0.15), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(Color.appSurface)
        .cornerRadius(20)
    }

    /// Built by concatenating `Text`, not by joining strings. The old
    /// `joined(separator:)` and the ternary "s" on the photo count never reached
    /// the string catalog at all, and languages such as Russian have four plural
    /// forms rather than two. Each fragment is now its own translatable unit.
    private func todaySummaryLine(_ entry: DiaryEntry) -> Text {
        // Quick-logged entries never captured a real energyLevel — it's just
        // DiaryEntryDraft's static default — so showing "Energy: 4/5" here
        // would present a fabricated number as if the user reported it.
        var line = Text("Mood: \(entry.moodTitle)") + Text(verbatim: " • ")
        line = line + (entry.isQuickLog ? Text("Quick log") : Text("Energy: \(entry.energyLevel)/5"))

        if !entry.photoIds.isEmpty {
            line = line + Text(verbatim: " • ") + Text("\(entry.photoIds.count) photos attached")
        }
        return line
    }

    // MARK: - Stats grid

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            // Each tile names its period: three metrics cover seven days while the
            // photo count covers all time, and nothing used to distinguish them.
            // String(format:) takes the decimal separator from POSIX rather than the
            // locale, printing "4.2" where "4,2" is expected; `format: .number` does
            // respect the locale.
            statCard(title: "7-DAY AVG MOOD", value: "\(viewModel.avgMoodScore, format: .number.precision(.fractionLength(1))) /5", icon: "sun.max.fill", iconColor: .yellow)
            statCard(title: "7-DAY AVG ENERGY", value: "\(viewModel.avgEnergyLevel, format: .number.precision(.fractionLength(1))) /5", icon: "bolt.fill", iconColor: .accentPrimary)
            statCard(title: "PROGRESS PHOTOS · ALL TIME", value: "\(viewModel.totalPhotosLogged) logged", icon: "camera.fill", iconColor: .textPrimary.opacity(0.6))
            statCard(title: "7-DAY SLEEP AVERAGE", value: "\(viewModel.avgSleepHours, format: .number.precision(.fractionLength(1))) hrs", icon: "moon.fill", iconColor: .purple)
        }
        .padding(.horizontal)
    }

    private func statCard(title: LocalizedStringKey, value: LocalizedStringKey, icon: String, iconColor: Color) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption2.weight(.heavy))
                    .foregroundColor(.textPrimary.opacity(0.4))
                Text(value)
                    .font(.title3.weight(.bold))
                    .foregroundColor(.textPrimary)
            }
            Spacer()
            Image(systemName: icon)
                .foregroundColor(iconColor)
        }
        .padding(16)
        .background(Color.appSurface)
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
                        // Three tabs split the width evenly, and "Progress Gallery"
                        // is "Fortschrittsgalerie" in German.
                        Text(tab.title)
                            .font(.caption.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        if let count = subTabCount(tab) {
                            Text("(\(count))")
                                .font(.caption2)
                                .foregroundColor(.textPrimary.opacity(0.4))
                        }
                    }
                    .foregroundColor(selectedSubTab == tab ? .accentPrimary : .textPrimary.opacity(0.5))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(selectedSubTab == tab ? Color.appSurface : Color.clear)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.textPrimary.opacity(0.08), lineWidth: 1))
        .cornerRadius(14)
        .padding(.horizontal)
    }

    private func subTabCount(_ tab: DiarySubTab) -> Int? {
        switch tab {
        case .journalFeed: return viewModel.entries.count
        case .progressGallery: return viewModel.photoCheckpoints.count
        case .moodTrends: return nil
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch selectedSubTab {
        case .journalFeed:
            DiaryJournalFeedView(
                entries: viewModel.entries,
                onEdit: { entryBeingEdited = $0 },
                onDelete: { entry in
                    entryToDelete = entry
                    showingDeleteAlert = true
                }
            )

        case .progressGallery:
            DiaryProgressGalleryView(
                checkpoints: viewModel.photoCheckpoints,
                selection: $comparisonSelection,
                onInspect: { inspectingPhoto = DiaryPhotoInspection(id: $0) },
                onLaunchComparison: openComparison
            )

        case .moodTrends:
            DiaryMoodTrendsView(
                entries: viewModel.entries,
                avgEnergyLevel: viewModel.avgEnergyLevel,
                avgSleepHours: viewModel.avgSleepHours
            )
        }
    }

    // MARK: - Comparison

    /// Opens the before/after comparison, from the header and from a gallery
    /// card alike. With fewer than two checkpoints selected it falls back to the
    /// earliest and the latest photo — baseline against latest progress; the
    /// screen itself lets the user swap either one.
    private func openComparison() {
        let checkpoints = viewModel.photoCheckpoints

        if comparisonSelection.count == 2 {
            let selected = comparisonSelection
                .compactMap { id in checkpoints.first { $0.id == id } }
                .sorted { $0.entry.checkInDate < $1.entry.checkInDate }
            guard selected.count == 2 else { return }
            comparisonPayload = DiaryComparisonPayload(beforeId: selected[0].id, afterId: selected[1].id)
            return
        }

        let sorted = checkpoints.sorted { $0.entry.checkInDate < $1.entry.checkInDate }
        guard let first = sorted.first, let last = sorted.last, sorted.count >= 2 else {
            withAnimation { selectedSubTab = .progressGallery }
            return
        }
        comparisonPayload = DiaryComparisonPayload(beforeId: first.id, afterId: last.id)
    }
}

extension DiaryView where VM == DiaryViewModel {
    init() {
        self.init(viewModel: DIContainer.shared.resolve(DiaryViewModel.self))
    }
}

#Preview {
    NavigationStack {
        DiaryView(viewModel: MockDiaryViewModel())
            .appTheme()
    }
}
