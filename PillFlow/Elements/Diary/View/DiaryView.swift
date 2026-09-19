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

/// One id shared by the zoom transition's source and destination.
private let comparisonSourceID = "diary.comparison"

struct DiaryView<VM: DiaryViewModelProtocol>: View {
    @StateObject private var viewModel: VM
    @EnvironmentObject private var router: AppRouter
    
    @State private var showingCheckIn = false
    @State private var showingBloodPressureEntry = false
    @State private var entryBeingEdited: DiaryEntry?
    @State private var showingDeleteAlert = false
    @State private var entryToDelete: DiaryEntry?
    
    @State private var selectedSubTab: DiarySubTab = .journalFeed
    @State private var comparisonSelection: [UUID] = []
    @State private var comparisonPayload: DiaryComparisonPayload?
    @State private var inspectingPhoto: DiaryPhotoInspection?
    
    @Namespace private var comparisonTransition
    
    init(viewModel: @autoclosure @escaping () -> VM) {
        self._viewModel = StateObject(wrappedValue: viewModel())
    }
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    DiaryHeaderView(
                        transitionSourceID: comparisonSourceID,
                        transitionNamespace: comparisonTransition,
                        onCompare: { openComparison() },
                        onAddEntry: { showingCheckIn = true }
                    )
                    
                    DiaryTodayCard(
                        entry: viewModel.todaysEntry,
                        quickMoods: DiaryTodayCard.QuickMood.standard,
                        onQuickLog: { viewModel.quickLog(mood: $0) },
                        onEdit: { entryBeingEdited = $0 }
                    )
                    
                    bloodPressureSection
                    
                    DiaryStatsGrid(
                        avgMoodScore: viewModel.avgMoodScore,
                        avgEnergyLevel: viewModel.avgEnergyLevel,
                        totalPhotosLogged: viewModel.totalPhotosLogged,
                        avgSleepHours: viewModel.avgSleepHours
                    )
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
        .sheet(isPresented: $showingBloodPressureEntry) {
            BloodPressureEntryView { measuredAt, systolic, diastolic, pulse in
                viewModel.addBloodPressureReading(
                    measuredAt: measuredAt, systolic: systolic, diastolic: diastolic, pulse: pulse
                )
            }
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
            .navigationTransition(.zoom(sourceID: comparisonSourceID, in: comparisonTransition))
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
        .task { applyPendingSubTab() }
        .onChange(of: router.pendingDiarySubTab) { _, _ in applyPendingSubTab() }
    }
    
    private func applyPendingSubTab() {
        guard let tab = router.consumePendingDiarySubTab() else { return }
        withAnimation { selectedSubTab = tab }
    }
    
    // MARK: - Blood pressure
    
    private var bloodPressureSection: some View {
        BloodPressureCard(
            readings: viewModel.bloodPressureReadings,
            onAdd: { showingBloodPressureEntry = true },
            onDelete: { viewModel.deleteBloodPressureReading($0) },
            onDeleteAll: { viewModel.deleteAllBloodPressureReadings() }
        )
        .padding(.horizontal)
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
                        Text(tab.title)
                            .font(.caption.weight(.bold))
                            .lineLimit(2)
                            .minimumScaleFactor(0.9)
                        if let count = subTabCount(tab) {
                            Text("(\(count))")
                                .font(.caption2)
                                .foregroundColor(.textSecondary)
                        }
                    }
                    .foregroundColor(selectedSubTab == tab ? .accentPrimary : .textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(selectedSubTab == tab ? Color.appSurface : Color.clear)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .expandTouchTarget(vertical: 4, horizontal: 0)
                .accessibilityAddTraits(selectedSubTab == tab ? .isSelected : [])
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
    /// card alike.
    private func openComparison() {
        guard let pair = viewModel.comparisonPair(for: comparisonSelection) else {
            withAnimation { selectedSubTab = .progressGallery }
            return
        }
        comparisonPayload = DiaryComparisonPayload(beforeId: pair.before, afterId: pair.after)
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
    .environmentObject(AppRouter())
}
