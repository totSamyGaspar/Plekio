//
//  DiaryView.swift
//  Plekio
//
//  Created by Edward Gasparian on 24.08.2026.
//

import SwiftUI

// MARK: - Presentation Items

/// A photo opened full-screen, wrapped for `.sheet(item:)`.
private struct DiaryPhotoInspection: Identifiable {
    let id: UUID
}

/// Before/after pair resolved before presenting, so `.sheet(item:)` never opens
/// ahead of its state (a Bool flag plus derived selection can show a blank sheet).
private struct DiaryComparisonPayload: Identifiable {
    let id = UUID()
    let beforeId: UUID
    let afterId: UUID
}

/// Ids shared by each zoom transition's source button and its sheet.
private let comparisonSourceID = "diary.comparison"
private let newEntrySourceID = "diary.newEntry"

// MARK: - DiaryView

struct DiaryView<VM: DiaryViewModelProtocol>: View {

    // MARK: - Properties

    @Environment(AppDependencies.self) private var dependencies
    @StateObject private var viewModel: VM
    @EnvironmentObject private var router: AppRouter

    @State private var showingCheckIn = false
    @State private var showingBloodPressureEntry = false
    @State private var entryBeingEdited: DiaryEntrySnapshot?
    @State private var showingDeleteAlert = false
    @State private var entryToDelete: DiaryEntrySnapshot?

    @State private var selectedSubTab: DiarySubTab = .journalFeed
    @Namespace private var subTabSelection
    @State private var comparisonSelection: [UUID] = []
    @State private var comparisonPayload: DiaryComparisonPayload?
    @State private var inspectingPhoto: DiaryPhotoInspection?

    @Namespace private var transitions

    // MARK: - Init

    init(viewModel: @autoclosure @escaping () -> VM) {
        self._viewModel = StateObject(wrappedValue: viewModel())
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    DiaryHeaderView(
                        compareSourceID: comparisonSourceID,
                        newEntrySourceID: newEntrySourceID,
                        transitionNamespace: transitions,
                        onCompare: { openComparison() },
                        onAddEntry: { showingCheckIn = true }
                    )

                    DiaryTodayCard(
                        entry: viewModel.todaysEntry,
                        quickMoods: DiaryTodayCard.QuickMood.standard,
                        onQuickLog: { mood in
                            if viewModel.quickLog(mood: mood) {
                                dependencies.toasts.show(.success("Mood logged"))
                            }
                        },
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
            DiaryCheckInView(viewModel: dependencies.makeDiaryCheckInViewModel())
                .navigationTransition(.zoom(sourceID: newEntrySourceID, in: transitions))
                .appTheme()
        }
        .sheet(isPresented: $showingBloodPressureEntry) {
            BloodPressureEntryView { measuredAt, systolic, diastolic, pulse in
                if viewModel.addBloodPressureReading(
                    measuredAt: measuredAt, systolic: systolic, diastolic: diastolic, pulse: pulse
                ) {
                    dependencies.toasts.show(.success("Blood pressure saved"))
                }
            }
            .navigationTransition(.zoom(sourceID: BloodPressureCard.addSourceID, in: transitions))
        }
        .sheet(item: $entryBeingEdited) { entry in
            DiaryCheckInView(viewModel: dependencies.makeDiaryCheckInViewModel(), editingEntry: entry)
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
            .navigationTransition(.zoom(sourceID: comparisonSourceID, in: transitions))
            .appTheme()
        }
        .alert("Delete Check-in?", isPresented: $showingDeleteAlert, presenting: entryToDelete) { entry in
            Button("Delete", role: .destructive) {
                if viewModel.deleteEntry(entry) {
                    dependencies.toasts.show(.success("Entry deleted"))
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This diary entry and its photos will be permanently removed.")
        }
        .task { applyPendingSubTab() }
        .onChange(of: router.pendingDiarySubTab) { _, _ in applyPendingSubTab() }
    }

    // MARK: - Routing

    private func applyPendingSubTab() {
        guard let tab = router.consumePendingDiarySubTab() else { return }
        withMotion { selectedSubTab = tab }
    }

    // MARK: - Blood Pressure

    private var bloodPressureSection: some View {
        BloodPressureCard(
            readings: viewModel.bloodPressureReadings,
            transitions: transitions,
            onAdd: { showingBloodPressureEntry = true },
            onDelete: { viewModel.deleteBloodPressureReading($0) },
            onDeleteAll: { viewModel.deleteAllBloodPressureReadings() }
        )
        .padding(.horizontal)
    }

    // MARK: - Sub-tab Bar

    private var subTabBar: some View {
        HStack(spacing: 6) {
            ForEach(DiarySubTab.allCases) { tab in
                Button {
                    withMotion { selectedSubTab = tab }
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
                    .selectionAnchor(tab, in: subTabSelection)
                }
                .buttonStyle(.plain)
                .expandTouchTarget(vertical: 4, horizontal: 0)
                .accessibilityAddTraits(selectedSubTab == tab ? .isSelected : [])
            }
        }
        .selectionIndicator(
            following: selectedSubTab,
            in: subTabSelection,
            shape: RoundedRectangle(cornerRadius: 12),
            fill: .appSurface
        )
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

    /// Falls back to the gallery tab when the selection doesn't form a pair.
    private func openComparison() {
        guard let pair = viewModel.comparisonPair(for: comparisonSelection) else {
            // Fewer than two photos: nothing to compare yet.
            dependencies.toasts.show(.info("Add at least two progress photos to compare"))
            return
        }
        comparisonPayload = DiaryComparisonPayload(beforeId: pair.before, afterId: pair.after)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DiaryView(viewModel: MockDiaryViewModel())
            .appTheme()
    }
    .environmentObject(AppRouter())
    .environment(AppDependencies.preview)
}
