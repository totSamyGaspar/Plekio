//
//  DashboardViewModel.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI
import Combine

@MainActor
@Observable
final class DashboardViewModel: DashboardViewModelProtocol {

    // MARK: - Properties

    /// Set from `time` in init; this placeholder is never read.
    var selectedDate: Date = .distantPast {
        didSet {
            fetchData()
            // The undo banner refers to the previous day's doses.
            clearUndoWindow()
        }
    }
    private var allPills: [PillDose] = []
    private(set) var hasCourses = true
    var weeklyPercentages: [Double] = Array(repeating: 0.0, count: 7)
    var weeklyDays: [String] = []
    var recentAverage: Int = 0
    var adherenceLevel: AdherenceLevel?

    /// Shared with the notification modal via DoseUndoCenter.
    var undoableAction: UndoableDoseAction? { undoCenter.current }

    /// Read-only; all dose writes go through `doseLogging`.
    private let dbService: any CourseStoring & DoseStoring
    private let doseLogging: DoseLoggingUseCaseProtocol
    private let errors: any ErrorReporting
    private let time: any TimeSource
    private let undoCenter: DoseUndoCenter
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()

    /// Course and dose writes announced so far, and how many of them the last load saw.
    /// An action reloads at once, so the debounced echo of its own write is skipped.
    @ObservationIgnored private var changeCount = 0
    @ObservationIgnored private var loadedChangeCount = 0

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter
    }()

    // MARK: - Init

    init(
        dbService: any CourseStoring & DoseStoring & DatabaseChangeSource,
        doseLogging: DoseLoggingUseCaseProtocol,
        errors: any ErrorReporting,
        time: any TimeSource = SystemTime(),
        undoCenter: DoseUndoCenter? = nil
    ) {
        self.dbService = dbService
        self.doseLogging = doseLogging
        self.errors = errors
        self.time = time
        // Private undo center when none is shared (tests).
        self.undoCenter = undoCenter ?? DoseUndoCenter(doseLogging: doseLogging, errors: errors, time: time)
        self.selectedDate = time.now
        fetchData()
        refreshHasCourses()

        let dayChanges = dbService.changes.publisher(for: [.courses, .doses])

        // Counted as they happen, not after the debounce, so a load can tell what it already covers.
        dayChanges
            .sink { [weak self] _ in self?.changeCount += 1 }
            .store(in: &cancellables)

        dayChanges
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.reloadIfStale() }
            .store(in: &cancellables)

        // Separate from fetchData: that one is served from the day cache, this needs a course read.
        dbService.changes.publisher(for: [.courses])
            .sink { [weak self] _ in self?.refreshHasCourses() }
            .store(in: &cancellables)
    }

    /// Builds the default use case; used by tests and previews.
    convenience init(dbService: any CourseStoring & DoseStoring & DatabaseChangeSource, notificationService: NotificationServiceProtocol) {
        self.init(
            dbService: dbService,
            doseLogging: DoseLoggingUseCase(dbService: dbService, notificationService: notificationService),
            errors: AppErrorPresenter()
        )
    }

    // MARK: - Derived state

    var weekDates: [Date] {
        let calendar = time.calendar
        let today = calendar.startOfDay(for: time.now)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }

    var morningPills: [PillDose] { allPills.filter { $0.period == .morning } }
    var noonPills: [PillDose] { allPills.filter { $0.period == .noon } }
    var eveningPills: [PillDose] { allPills.filter { $0.period == .evening } }

    var isEmpty: Bool { allPills.isEmpty }

    // MARK: - Data Loading

    private func fetchData() {
        loadedChangeCount = changeCount
        let pills = dbService.fetchPills(for: selectedDate, preFetchedCourses: nil)

        if pills != allPills {
            allPills = pills
        }

        calculateWeeklyStats()
    }

    /// Skips the reload when every write since the last load was already in it.
    private func reloadIfStale() {
        guard changeCount != loadedChangeCount else { return }
        fetchData()
    }

    private func refreshHasCourses() {
        let exists = !dbService.fetchAllCourses().isEmpty
        if hasCourses != exists { hasCourses = exists }
    }

    // MARK: - Actions

    func togglePill(id: PillDose.ID) {
        guard let pill = allPills.first(where: { $0.id == id }),
              errors.attempt({ try doseLogging.toggle(pill) }) != nil
        else { return }

        fetchData()
    }

    /// "Log all": logs the slot and offers an undo banner.
    func logDoses(_ doses: [PillDose]) {
        guard let outcome = errors.attempt({ try doseLogging.markTaken(doses) }),
              outcome.didWrite
        else { return }

        fetchData()
        startUndoWindow(.logged, undo: outcome.undo)
    }

    /// A deliberate skip from the card's menu; undoable like "Log all".
    func skipDose(id: PillDose.ID) {
        guard let pill = allPills.first(where: { $0.id == id }),
              let outcome = errors.attempt({ try doseLogging.markSkipped([pill]) }),
              outcome.didWrite
        else { return }

        fetchData()
        startUndoWindow(.skipped, undo: outcome.undo)
    }

    /// The use case checks current storage, so doses changed since aren't flipped back.
    func undoLastAction() {
        if undoCenter.undo() {
            fetchData()
        }
    }

    func dismissUndo() {
        clearUndoWindow()
    }

    // MARK: - Undo window

    private func startUndoWindow(_ kind: UndoableDoseAction.Kind, undo: DoseCommand?) {
        undoCenter.offer(kind, undo: undo)
    }

    private func clearUndoWindow() {
        undoCenter.dismiss()
    }

    // MARK: - Weekly statistics

    /// The in-flight week read. Exposed so tests can await it.
    private(set) var weeklyLoad: Task<Void, Never>?

    /// The week is read off the main actor; today's list stays synchronous so a tap shows at once.
    private func calculateWeeklyStats() {
        let calendar = time.calendar
        let now = time.now
        let dates = (0..<7).reversed().map { calendar.date(byAdding: .day, value: -$0, to: now) ?? now }

        weeklyLoad?.cancel()
        weeklyLoad = Task { [weak self, dbService] in
            let pillsByDay = await dbService.pillHistory(onDays: dates)
            guard !Task.isCancelled, let self else { return }
            self.applyWeeklyStats(pillsByDay, dates: dates, now: now, calendar: calendar)
        }
    }

    /// Only settled doses are graded: one still pending within its grace window
    /// (later today, say) is neither taken nor missed yet, so a course created
    /// this morning does not open at 0%.
    private func applyWeeklyStats(_ pillsByDay: [Date: [PillDose]], dates: [Date], now: Date, calendar: Calendar) {
        var percentages: [Double] = []
        var daysLabels: [String] = []

        var adherenceSum = 0.0
        var daysWithDoses = 0

        for date in dates {
            daysLabels.append(Self.weekdayFormatter.string(from: date))

            let dailyPills = (pillsByDay[calendar.startOfDay(for: date)] ?? [])
                .filter { $0.status != .pending || $0.isMissed(at: now) }
            if dailyPills.isEmpty {
                percentages.append(0.0)
            } else {
                let taken = dailyPills.filter { $0.isTaken }.count
                let percent = Double(taken) / Double(dailyPills.count)
                percentages.append(percent)
                adherenceSum += percent
                daysWithDoses += 1
            }
        }

        if weeklyPercentages != percentages { weeklyPercentages = percentages }
        if weeklyDays != daysLabels { weeklyDays = daysLabels }

        let average = daysWithDoses > 0
        ? Int((adherenceSum / Double(daysWithDoses)) * 100)
        : 0
        if recentAverage != average { recentAverage = average }

        let level = daysWithDoses > 0 ? AdherenceLevel(percent: average) : nil
        if adherenceLevel != level { adherenceLevel = level }
    }
}
