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
            Color.bgDark.ignoresSafeArea()
            let allTakenStates = (viewModel.morningPills + viewModel.noonPills + viewModel.eveningPills).map { $0.isTaken }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerSection
                    dateSummaryCard

                    let isToday = Calendar.current.isDateInToday(viewModel.selectedDate)

                    if isToday {
                        let allPills = viewModel.morningPills + viewModel.noonPills + viewModel.eveningPills

                        // Missed doses (past the 1-hour grace window) are excluded here too —
                        // otherwise a missed dose would still surface as "Up Next" with a
                        // working Log button, bypassing the same lock MedicationCardView enforces.
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
                        emptyStateView
                    } else {
                        timelineSection
                    }
                }
                .padding(.bottom, 100)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: allTakenStates)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: router.pendingPushMedicationIds) { _, newValue in
            guard newValue != nil else { return }
            if let (medIds, _) = router.consumePendingPush() {

                let allCurrentPills = viewModel.morningPills + viewModel.noonPills + viewModel.eveningPills
                let pillsToTake = allCurrentPills.filter { medIds.contains($0.medicationId) }

                if !pillsToTake.isEmpty {
                    router.presentFullScreen(
                        .takePill(
                            pills: pillsToTake,
                            onTake: {
                                for pill in pillsToTake {
                                    viewModel.togglePill(id: pill.id)
                                }
                            },
                            onSkip: {
                                let notifService = DIContainer.shared.resolve(NotificationServiceProtocol.self)
                                for pill in pillsToTake {
                                    notifService.cancelNotifications(for: pill.medicationId)
                                }
                            }
                        )
                    )
                }
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PillFlow")
                .font(.system(size: 36, weight: .heavy, design: .serif))
                .italic()
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, 10)
    }

    private var dateSummaryCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(Date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.title3.weight(.bold))
                    .foregroundColor(.white)

                let total = viewModel.morningPills.count + viewModel.noonPills.count + viewModel.eveningPills.count
                let taken = (viewModel.morningPills + viewModel.noonPills + viewModel.eveningPills).filter { $0.isTaken }.count

                Text("\(taken) of \(total) doses logged today")
                    .font(.subheadline)
                    .foregroundColor(.neonMint)
            }
            Spacer()
            Circle()
                .fill(Color.neonMint)
                .frame(width: 46, height: 46)
                .overlay(
                    Text("PF").font(.headline.weight(.heavy)).foregroundColor(Color.bgDark)
                )
        }
        .padding(20)
        .background(Color.cardDark)
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
                        .font(.system(size: 24, weight: .heavy, design: .serif))
                        .foregroundColor(.white)
                    Text("Your medications for today")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 16)

            let isToday = Calendar.current.isDateInToday(viewModel.selectedDate)

            // Shared helper for all three periods so morning/noon/evening
            // sections stay behaviorally identical instead of drifting apart.
            periodSection(pills: viewModel.morningPills, title: DayPeriod.morning.rawValue, timeString: "8:00 AM", isToday: isToday)
            periodSection(pills: viewModel.noonPills, title: DayPeriod.noon.rawValue, timeString: "1:00 PM", isToday: isToday)
            periodSection(pills: viewModel.eveningPills, title: DayPeriod.evening.rawValue, timeString: "7:00 PM", isToday: isToday)
        }
    }

    @ViewBuilder
    private func periodSection(pills: [PillDose], title: String, timeString: String, isToday: Bool) -> some View {
        if !pills.isEmpty {
            PeriodSectionView(
                title: title,
                timeString: timeString,
                pills: pills,
                isToday: isToday,
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

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)
            Image(systemName: "pills")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))
            Text("Nothing for today")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
}

extension DashboardView where VM == DashboardViewModel {
    init() {
        self.init(viewModel: DIContainer.shared.resolve((any DashboardViewModelProtocol).self) as! VM)
    }
}

#Preview {
    DashboardView(viewModel: MockDashboardViewModel())
        .environmentObject(AppRouter())
        .preferredColorScheme(.dark)
}
