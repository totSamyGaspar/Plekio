//
//  DashboardView.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI

struct DashboardView<VM: DashboardViewModelProtocol>: View {

    // MARK: - Properties

    @Environment(AppDependencies.self) private var dependencies
    @StateObject private var viewModel: VM
    @EnvironmentObject private var router: AppRouter

    /// Scales with the wordmark's text style under Dynamic Type.
    @ScaledMetric(relativeTo: .largeTitle) private var logoSize: CGFloat = 34

    // MARK: - Init

    init(viewModel: @autoclosure @escaping () -> VM) {
        self._viewModel = StateObject(wrappedValue: viewModel())
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.appBackground.ignoresSafeArea()
            let allTakenStates = (viewModel.morningPills + viewModel.noonPills + viewModel.eveningPills).map { $0.isTaken }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerSection

                    if let upNextPills {
                        UpNextHeroCard(
                            pills: upNextPills,
                            selectedDate: viewModel.selectedDate,
                            takenCount: takenCount,
                            totalCount: totalCount
                        ) {
                            viewModel.logDoses(upNextPills)
                        }
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
                        EmptyStateView(icon: "pills", title: "Nothing for today", verticalPadding: 60)
                    } else {
                        timelineSection
                    }
                    StatisticsView(viewModel: dependencies.makeStatisticsViewModel())
                }
                .padding(.bottom, 100)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: allTakenStates)
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
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.undoableAction)
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

    private var calendarSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.weekDates, id: \.self) { date in
                    CalendarDayView(
                        date: date,
                        isSelected: Calendar.current.isDate(date, inSameDayAs: viewModel.selectedDate)
                    )
                    .onTapGesture {
                        withAnimation { viewModel.selectedDate = date }
                    }
                }
            }
            .padding(.horizontal)
        }
        .sensoryFeedback(.selection, trigger: viewModel.selectedDate)
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

            periodSection(pills: viewModel.morningPills, title: DayPeriod.morning.title)
            periodSection(pills: viewModel.noonPills, title: DayPeriod.noon.title)
            periodSection(pills: viewModel.eveningPills, title: DayPeriod.evening.title)
        }
    }

    @ViewBuilder
    private func periodSection(pills: [PillDose], title: LocalizedStringResource) -> some View {
        if !pills.isEmpty {
            PeriodSectionView(
                title: title,
                pills: pills,
                onTogglePill: { id in viewModel.togglePill(id: id) },
                onPillTap: { pill in
                    presentTakeSheet(
                        for: pills.filter { $0.time == pill.time && $0.status == .pending }
                    )
                }
            )
        }
    }

    // MARK: - Actions

    private func presentTakeSheet(for doses: [PillDose]) {
        guard !doses.isEmpty else { return }
        // Same route as a tapped reminder — see DoseSheetActions.
        router.presentFullScreen(.takePill(pills: doses))
    }
}

// MARK: - Preview

#Preview {
    DashboardView(viewModel: MockDashboardViewModel())
        .environmentObject(AppRouter())
        .environment(AppDependencies.preview)
        .appTheme()
}
