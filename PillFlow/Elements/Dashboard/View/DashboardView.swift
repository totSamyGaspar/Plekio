//
//  DashboardView.swift
//  PillFlow
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI

struct DashboardView<VM: DashboardViewModelProtocol>: View {
    @StateObject private var viewModel: VM
    @EnvironmentObject private var router: AppRouter

    init(viewModel: @autoclosure @escaping () -> VM) {
        self._viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.appBackground.ignoresSafeArea()
            let allTakenStates = (viewModel.morningPills + viewModel.noonPills + viewModel.eveningPills).map { $0.isTaken }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerSection
                    dateSummaryCard

                    let isToday = Calendar.current.isDateInToday(viewModel.selectedDate)

                    if isToday {
                        let allPills = viewModel.morningPills + viewModel.noonPills + viewModel.eveningPills

                        // Missed doses (past the 1-hour grace window) are excluded here too,
                        // or one would still surface as "Up Next" with a working Log button,
                        // bypassing the lock MedicationCardView enforces.
                        if let earliestUntakenTime = allPills.filter({ !$0.isTaken && !$0.isMissed }).min(by: { $0.time < $1.time })?.time {

                            let pillsAtThisTime = allPills.filter { Calendar.current.isDate($0.time, equalTo: earliestUntakenTime, toGranularity: .minute) }

                            UpNextHeroCard(pills: pillsAtThisTime) {
                                for pill in pillsAtThisTime where !pill.isTaken && !pill.isMissed {
                                    viewModel.togglePill(id: pill.id)
                                }
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
                        }
                    }

                    calendarSection.padding(.top, 8)

                    if viewModel.isEmpty {
                        EmptyStateView(icon: "pills", title: "Nothing for today", verticalPadding: 60)
                    } else {
                        timelineSection
                    }
                    StatisticsView()
                }
                .padding(.bottom, 100)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: allTakenStates)
            }
        }
        .toolbar(.hidden, for: .navigationBar)

    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PillFlow")
                .scaledFont(size: 36, relativeTo: .largeTitle, weight: .heavy, design: .serif)
                .italic()
                .foregroundColor(.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    /// The monogram circle holds text, so it follows the text size.
    @ScaledMetric(relativeTo: .headline) private var monogramSize: CGFloat = 46

    private var dateSummaryCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                // The date and the counters now describe the same day. This used to
                // print today's date with the word "today" while the counter was
                // computed for the selected date, so the two disagreed as soon as the
                // user moved off today.
                Text(viewModel.selectedDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.title3.weight(.bold))
                    .foregroundColor(.textPrimary)

                let total = viewModel.morningPills.count + viewModel.noonPills.count + viewModel.eveningPills.count
                let taken = (viewModel.morningPills + viewModel.noonPills + viewModel.eveningPills).filter { $0.isTaken }.count

                Text("\(taken) of \(total) doses logged")
                    .font(.subheadline)
                    .foregroundColor(.accentPrimary)
            }
            Spacer()
            Circle()
                .fill(Color.accentPrimary)
                .frame(width: monogramSize, height: monogramSize)
                .overlay(
                    Text("PF").font(.headline.weight(.heavy)).foregroundColor(Color.onAccent)
                )
        }
        .padding(20)
        .background(Color.appSurface)
        .cornerRadius(20)
        .padding(.horizontal)
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
                    let sameTimePills = pills.filter { $0.time == pill.time }
                    router.presentFullScreen(
                        .takePill(
                            pills: sameTimePills,
                            onTake: {
                                for p in sameTimePills { viewModel.togglePill(id: p.id) }
                            },
                            onSkip: {
                                let notifService = DIContainer.shared.resolve(NotificationServiceProtocol.self)
                                for p in sameTimePills { notifService.cancelNotifications(for: p.medicationId) }
                            }
                        )
                    )
                }
            )
        }
    }

}

extension DashboardView where VM == DashboardViewModel {
    init() {
        self.init(viewModel: DIContainer.shared.resolve(DashboardViewModel.self))
    }
}

#Preview {
    DashboardView(viewModel: MockDashboardViewModel())
        .environmentObject(AppRouter())
        .appTheme()
}
