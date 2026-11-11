//
//  DashboardView.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI

struct DashboardView<VM: DashboardViewModelProtocol, Stats: StatisticsViewModelProtocol>: View {

    // MARK: - Properties

    @StateModel private var viewModel: VM
    /// Shared by the statistics section and the finished-day hero card.
    @StateModel private var statistics: Stats
    @Environment(AppRouter.self) private var router
    @Environment(AppDependencies.self) private var dependencies

    @State private var width: CGFloat = 0

    private static var twoColumnMinWidth: CGFloat { 780 }

    private var isWide: Bool { width >= Self.twoColumnMinWidth }

    private var overviewWidth: CGFloat { min(max(width * 0.4, 360), 460) }

    // MARK: - Init

    init(viewModel: @autoclosure @escaping () -> VM, statistics: @autoclosure @escaping () -> Stats) {
        self._viewModel = StateModel(wrappedValue: viewModel())
        self._statistics = StateModel(wrappedValue: statistics())
    }

    // MARK: - Derived state

    private var allPills: [PillDose] {
        viewModel.morningPills + viewModel.noonPills + viewModel.eveningPills
    }

    // MARK: - Body

    var body: some View {
        let pills = allPills
        let hero = DayHero(pills: pills, selectedDate: viewModel.selectedDate, now: .now, calendar: .current)
        // Statuses, not just "taken": a skip can also finish the day and swap the hero card.
        let statuses = pills.map(\.status)

        ZStack(alignment: .bottomTrailing) {
            Color.appBackground.ignoresSafeArea()
            spaceReader

            if isWide {
                wideLayout(hero: hero, statuses: statuses)
            } else {
                narrowLayout(hero: hero, statuses: statuses)
            }
        }
        .overlay(alignment: .bottom) {
            if let action = viewModel.undoableAction {
                UndoLogBanner(
                    kind: action.kind,
                    count: action.count,
                    startedAt: action.startedAt,
                    duration: UndoableDoseAction.window
                ) {
                    viewModel.undoLastAction()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .motion(Motion.standard, value: viewModel.undoableAction)
        .doseFeedback(for: pills)
        .requestsReviewAfterTaking(pills)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Layouts

    /// The space given, not the content: the content's width changes with the layout.
    private var spaceReader: some View {
        Color.clear
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .accessibilityHidden(true)
    }

    private func narrowLayout(hero: DayHero, statuses: [DoseStatus]) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                DashboardHeader()
                daySection(hero)

                if viewModel.isEmpty {
                    emptyDay
                } else {
                    VStack(spacing: 20) {
                        weeklyChart
                        doseTimeline
                    }
                }
                StatisticsView(viewModel: statistics)
            }
            .padding(.bottom, 100)
            .motion(Motion.progress, value: statuses)
        }
    }

    private func wideLayout(hero: DayHero, statuses: [DoseStatus]) -> some View {
        VStack(spacing: 16) {
            DashboardHeader()

            HStack(alignment: .top, spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        daySection(hero)

                        if viewModel.isEmpty {
                            emptyDay
                        } else {
                            doseTimeline
                        }
                    }
                    .padding(.bottom, 100)
                    .motion(Motion.progress, value: statuses)
                }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        if !viewModel.isEmpty {
                            weeklyChart
                        }
                        StatisticsView(viewModel: statistics)
                    }
                    .padding(.bottom, 100)
                    .motion(Motion.progress, value: statuses)
                }
                .frame(width: overviewWidth)
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func daySection(_ hero: DayHero) -> some View {
        @Bindable var viewModel = viewModel

        if viewModel.hasCourses, dependencies.reminderSync.delivery == .off {
            NotificationsOffCard()
                .transition(.opacity)
        }

        if let front = hero.front {
            heroCard(hero, front: front)
                .tourTarget(.upNextCard)
                .zIndex(1)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                            .combined(with: .scale(scale: 0.8))
                            .combined(with: .offset(y: -40))
                    )
                )
        } else {
            DaySummaryLine(date: viewModel.selectedDate, takenCount: hero.takenCount, totalCount: hero.totalCount)
        }

        WeekStrip(dates: viewModel.weekDates, selection: $viewModel.selectedDate)
            .padding(.top, 8)
    }

    /// "Up next" on the front; turns over to the day's summary once every dose is settled.
    private func heroCard(_ hero: DayHero, front pills: [PillDose]) -> some View {
        FlipCard(isFlipped: hero.isDayComplete) {
            UpNextHeroCard(
                pills: pills,
                selectedDate: viewModel.selectedDate,
                takenCount: hero.takenCount,
                totalCount: hero.totalCount
            ) {
                viewModel.logDoses(pills)
            }
        } back: {
            DayCompleteHeroCard(
                date: viewModel.selectedDate,
                takenCount: hero.takenCount,
                totalCount: hero.totalCount,
                streakDays: statistics.streakDays,
                isShown: hero.isDayComplete
            )
        }
    }

    private var emptyDay: some View {
        DashboardEmptyDay(hasCourses: viewModel.hasCourses) {
            router.present(.newTreatment)
        }
    }

    private var weeklyChart: some View {
        WeeklyAdherenceView(
            percentages: viewModel.weeklyPercentages,
            days: viewModel.weeklyDays,
            recentAverage: viewModel.recentAverage
        )
        .padding(.top, 10)
    }

    private var doseTimeline: some View {
        DoseTimeline(
            morning: viewModel.morningPills,
            noon: viewModel.noonPills,
            evening: viewModel.eveningPills
        ) { action, pill, section in
            handle(action, for: pill, in: section)
        }
    }

    // MARK: - Actions

    private func handle(_ action: DoseCardAction, for pill: PillDose, in section: [PillDose]) {
        switch action {
        case .toggle:
            viewModel.togglePill(id: pill.id)
        case .open:
            presentTakeSheet(for: section.filter { $0.time == pill.time && $0.status == .pending })
        case .skip:
            viewModel.skipDose(id: pill.id)
        case .showCourse:
            guard let courseId = pill.courseId else { return }
            router.showCourse(id: courseId)
        }
    }

    private func presentTakeSheet(for doses: [PillDose]) {
        guard !doses.isEmpty else { return }
        // Same route as a tapped reminder — see DoseSheetActions.
        router.presentFullScreen(.takePill(pills: doses))
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    DashboardView(viewModel: MockDashboardViewModel(), statistics: MockStatisticsViewModel())
        .environment(AppRouter())
        .environment(AppDependencies.preview)
        .appTheme()
}
#endif
