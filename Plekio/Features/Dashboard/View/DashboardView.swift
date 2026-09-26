//
//  DashboardView.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI
import TipKit

struct DashboardView<VM: DashboardViewModelProtocol, Stats: StatisticsViewModelProtocol>: View {

    // MARK: - Properties

    @StateObject private var viewModel: VM
    /// Shared by the statistics section and the finished-day hero card.
    @StateObject private var statistics: Stats
    @EnvironmentObject private var router: AppRouter

    /// Scales with the wordmark's text style under Dynamic Type.
    @ScaledMetric(relativeTo: .largeTitle) private var logoSize: CGFloat = 34

    @Namespace private var daySelection

    private let checkmarkTip = DoseCheckmarkTip()

    private var hasPills: Bool {
        !(viewModel.morningPills.isEmpty && viewModel.noonPills.isEmpty && viewModel.eveningPills.isEmpty)
    }

    // MARK: - Init

    init(viewModel: @autoclosure @escaping () -> VM, statistics: @autoclosure @escaping () -> Stats) {
        self._viewModel = StateObject(wrappedValue: viewModel())
        self._statistics = StateObject(wrappedValue: statistics())
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.appBackground.ignoresSafeArea()
            // Statuses, not just "taken": a skip can also finish the day and swap the hero card.
            let allStatuses = allPills.map(\.status)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerSection

                    if let heroPills {
                        heroCard(front: heroPills)
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
                        dateSummaryLine
                    }

                    calendarSection.padding(.top, 8)

                    if viewModel.isEmpty {
                        emptyDay
                    } else {
                        timelineSection
                    }
                    StatisticsView(viewModel: statistics, showsAdherence: !isDayComplete)
                }
                .padding(.bottom, 100)
                .motion(Motion.progress, value: allStatuses)
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
        .doseFeedback(for: allPills)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 10) {
            AppLogo(size: logoSize)

            Text(AppBrand.name)
                .scaledFont(size: 36, relativeTo: .largeTitle, weight: .heavy, design: .serif)
                .italic()
                .foregroundColor(.textPrimary)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    // MARK: - Derived state

    private var allPills: [PillDose] {
        viewModel.morningPills + viewModel.noonPills + viewModel.eveningPills
    }

    private var totalCount: Int { allPills.count }
    private var takenCount: Int { allPills.filter { $0.isTaken }.count }

    /// Next pending slot today; nil hides the hero card. Missed doses are excluded
    /// so the hero can't bypass MedicationCardView's missed-dose lock.
    /// Today, and every dose is taken or skipped: the hero card turns into the day's summary.
    private var isDayComplete: Bool {
        Calendar.current.isDateInToday(viewModel.selectedDate)
            && !allPills.isEmpty
            && allPills.allSatisfy(\.status.isSettled)
    }

    /// What the hero's front shows: the next slot, or once the day is done, the last one,
    /// which is what the card was showing just before it turns over.
    private var heroPills: [PillDose]? {
        if let upNextPills { return upNextPills }
        guard isDayComplete, let last = allPills.map(\.time).max() else { return nil }
        return allPills.filter { Calendar.current.isDate($0.time, equalTo: last, toGranularity: .minute) }
    }

    private var upNextPills: [PillDose]? {
        guard Calendar.current.isDateInToday(viewModel.selectedDate) else { return nil }
        guard let earliest = allPills
            .filter({ $0.status == .pending && !$0.isMissed })
            .min(by: { $0.time < $1.time })?.time
        else { return nil }
        return allPills.filter {
            Calendar.current.isDate($0.time, equalTo: earliest, toGranularity: .minute)
        }
    }

    // MARK: - Sections

    /// "Up next" on the front; turns over to the day's summary once every dose is settled.
    private func heroCard(front pills: [PillDose]) -> some View {
        FlipCard(isFlipped: isDayComplete) {
            UpNextHeroCard(
                pills: pills,
                selectedDate: viewModel.selectedDate,
                takenCount: takenCount,
                totalCount: totalCount
            ) {
                viewModel.logDoses(pills)
            }
        } back: {
            DayCompleteHeroCard(
                date: viewModel.selectedDate,
                takenCount: takenCount,
                totalCount: totalCount,
                streakDays: statistics.streakDays,
                isShown: isDayComplete
            )
        }
    }

    /// Shown instead of the hero card; describes the selected day, not today.
    private var dateSummaryLine: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.selectedDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(.title3.weight(.bold))
                .foregroundColor(.textPrimary)

            Text("\(takenCount) of \(totalCount) doses logged")
                .font(.subheadline)
                .foregroundColor(.accentPrimary)
                .animatedNumber(Double(takenCount))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }

    /// The week cell matching the selected day; nil once the week has moved past it.
    private var selectedWeekDate: Date? {
        viewModel.weekDates.first { Calendar.current.isDate($0, inSameDayAs: viewModel.selectedDate) }
    }

    private var calendarSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.weekDates, id: \.self) { date in
                    CalendarDayView(
                        date: date,
                        isSelected: Calendar.current.isDate(date, inSameDayAs: viewModel.selectedDate),
                        selection: daySelection
                    )
                    .onTapGesture {
                        withMotion { viewModel.selectedDate = date }
                    }
                }
            }
            .selectionIndicator(
                following: selectedWeekDate,
                in: daySelection,
                shape: RoundedRectangle(cornerRadius: 16),
                fill: .accentPrimary
            )
            .padding(.horizontal)
        }
        .sensoryFeedback(.selection, trigger: viewModel.selectedDate)
    }

    /// Before the first course, the empty day offers to create one.
    @ViewBuilder
    private var emptyDay: some View {
        if viewModel.hasCourses {
            EmptyStateView(icon: "pills", title: "Nothing for today", verticalPadding: 60)
        } else {
            EmptyStateView(
                icon: "pills",
                title: "Add your first course to see your doses here",
                verticalPadding: 60,
                actionTitle: "Create a course",
                action: { router.present(.newTreatment) }
            )
        }
    }

    private var timelineSection: some View {
        LazyVStack(spacing: 20) {
            WeeklyAdherenceView(
                percentages: viewModel.weeklyPercentages,
                days: viewModel.weeklyDays,
                recentAverage: viewModel.recentAverage
            )
            .padding(.top, 10)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Dosage Timeline")
                        .scaledFont(size: 24, relativeTo: .title2, weight: .heavy, design: .serif)
                        .foregroundColor(.textPrimary)
                    Text("Your medications for today")
                        .font(.subheadline)
                        .foregroundColor(.textPrimary.opacity(0.7))
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 16)

            if hasPills {
                TipView(checkmarkTip)
                    .padding(.horizontal)
            }

            periodSection(pills: viewModel.morningPills, title: DayPeriod.morning.title)
            periodSection(pills: viewModel.noonPills, title: DayPeriod.noon.title)
            periodSection(pills: viewModel.eveningPills, title: DayPeriod.evening.title)
        }
    }

    @ViewBuilder
    private func periodSection(pills: [PillDose], title: LocalizedStringResource) -> some View {
        if !pills.isEmpty {
            PeriodSectionView(title: title, pills: pills) { action, pill in
                handle(action, for: pill, in: pills)
            }
        }
    }

    // MARK: - Actions

    private func handle(_ action: DoseCardAction, for pill: PillDose, in section: [PillDose]) {
        switch action {
        case .toggle:
            checkmarkTip.invalidate(reason: .actionPerformed)
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

#Preview {
    DashboardView(viewModel: MockDashboardViewModel(), statistics: MockStatisticsViewModel())
        .environmentObject(AppRouter())
        .environment(AppDependencies.preview)
        .appTheme()
}
