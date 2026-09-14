//
//  DashboardViewModel.swift
//  PillFlow
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI
import Combine

@MainActor
final class DashboardViewModel: DashboardViewModelProtocol {
    
    @Published var selectedDate: Date = Date() {
        didSet {
            fetchData()
            // The banner names doses on the day that was on screen when it was
            // tapped; carrying it over to another day would offer to undo
            // something the user can no longer see.
            clearUndoWindow()
        }
    }
    @Published private var allPills: [PillDose] = []
    @Published var weeklyPercentages: [Double] = Array(repeating: 0.0, count: 7)
    @Published var weeklyDays: [String] = []
    @Published var recentAverage: Int = 0
    
    
    /// The last "Log all", while it can still be undone. Nil at every other time.
    @Published private(set) var undoableBulkLog: BulkDoseLog?
    
    private let dbService: any CourseStoring & DoseStoring
    private let notificationService: NotificationServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    /// Closes the undo window on its own. Held so a second "Log all" replaces the
    /// first countdown instead of racing it.
    private var undoExpiryTask: Task<Void, Never>?
    
    /// Long enough to notice the banner, read it and work out what it offers —
    /// the mistap is realised a beat after it happens, not during it — and still
    /// short enough that the banner is gone before it becomes furniture.
    private static let undoWindow: Duration = .seconds(10)
    
    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter
    }()
    
    // MARK: - Init
    
    init(dbService: any CourseStoring & DoseStoring, notificationService: NotificationServiceProtocol) {
        self.dbService = dbService
        self.notificationService = notificationService
        fetchData()
        
        // Doses as well as courses: this screen is where a dose is logged.
        NotificationCenter.default.publisher(forDatabaseChanges: [.courses, .doses])
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.fetchData()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Computed Properties
    
    var weekDates: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }
    
    var morningPills: [PillDose] { allPills.filter { $0.period == .morning } }
    var noonPills: [PillDose] { allPills.filter { $0.period == .noon } }
    var eveningPills: [PillDose] { allPills.filter { $0.period == .evening } }
    
    var isEmpty: Bool { allPills.isEmpty }
    
    // MARK: - Data Loading
    
    private func fetchData() {
        let allCourses = dbService.fetchAllCourses()
        
        let pills = dbService.fetchPills(for: selectedDate, preFetchedCourses: allCourses)
        
        if pills != allPills {
            allPills = pills
        }
        
        calculateWeeklyStats(with: allCourses)
    }
    
    // MARK: - Actions
    
    func togglePill(id: PillDose.ID) {
        guard let pill = allPills.first(where: { $0.id == id }) else { return }
        let wasTaken = pill.isTaken
        
        guard AppErrorPresenter.shared.run({
            try dbService.togglePill(medicationId: pill.medicationId, scheduledTime: pill.time)
        }) else { return }
        
        // The UI is refreshed straight away; the notification work is ordered
        // behind the rebuild inside one task rather than racing it.
        fetchData()
        
        let takenAtSlot = wasTaken ? [] : allPills
            .filter { $0.time == pill.time && $0.isTaken }
            .map(\.medicationId)
        let slot = pill.time
        
        Task { [notificationService, dbService] in
            await notificationService.rescheduleAll(using: dbService)
            guard !takenAtSlot.isEmpty else { return }
            await notificationService.clearDelivered(
                settledMedicationIds: takenAtSlot,
                scheduledTime: slot
            )
        }
    }
    
    /// Logs several doses as one action, so "Log all" costs one write pass and one
    /// notification rebuild rather than one of each per dose.
    func logDoses(_ doses: [PillDose]) {
        // Only "already taken" is filtered out. Being late is not a reason to
        // refuse the write: the caller decides what to offer (the hero card passes
        // only doses that are still due), and a confirmation that crosses the
        // missed threshold while the sheet is open must still be logged.
        let pending = doses.filter { !$0.isTaken }
        guard !pending.isEmpty else { return }
        
        // One write per slot, not per dose. Each togglePill was its own commit,
        // its own cache reset and its own change notification — and a toggle on a
        // list of doses in unknown states is the wrong verb besides.
        guard AppErrorPresenter.shared.run({
            for (slot, doses) in Dictionary(grouping: pending, by: \.time) {
                try dbService.markDosesTaken(
                    medicationIds: doses.map(\.medicationId),
                    scheduledTime: slot
                )
            }
        }) else { return }
        
        fetchData()
        refreshNotifications(forSlotsOf: pending)
        startUndoWindow(with: pending)
    }
    
    /// The sheet's "Skip" / "Skip All".
    ///
    /// Written down rather than merely un-notified: the statistics can now tell a
    /// declined dose from a forgotten one, and the rebuild below leaves the rest
    /// of the course alone.
    func skipDoses(_ doses: [PillDose]) {
        guard let bySlot = PendingDose.recordSkip(doses, dbService: dbService),
              !bySlot.isEmpty
        else { return }
        
        fetchData()
        
        Task { [dbService, notificationService] in
            await PendingDose.refreshAfterSkip(
                slots: Array(bySlot.keys),
                dbService: dbService,
                notificationService: notificationService
            )
        }
    }
    
    /// Puts back exactly what the last "Log all" wrote.
    func undoBulkLog() {
        guard let log = undoableBulkLog else { return }
        clearUndoWindow()
        
        // Only doses that are still marked taken: the user may have unticked one
        // by hand in the meantime, and toggling that one again would log it
        // rather than undo it.
        let toRevert = log.doses.filter { dose in
            allPills.first { $0.id == dose.id }?.isTaken == true
        }
        guard !toRevert.isEmpty else { return }
        
        guard AppErrorPresenter.shared.run({
            for (slot, doses) in Dictionary(grouping: toRevert, by: \.time) {
                try dbService.unmarkDosesTaken(
                    medicationIds: doses.map(\.medicationId),
                    scheduledTime: slot
                )
            }
        }) else { return }
        
        fetchData()
        // Rebuilt rather than left alone: the reminders for these slots were
        // dropped when the doses were logged, and the whole point of the undo is
        // that they come back.
        Task { [notificationService, dbService] in
            await notificationService.rescheduleAll(using: dbService)
        }
    }
    
    func dismissUndo() {
        clearUndoWindow()
    }
    
    // MARK: - Undo window
    
    private func startUndoWindow(with doses: [PillDose]) {
        undoExpiryTask?.cancel()
        undoableBulkLog = BulkDoseLog(doses: doses)
        
        undoExpiryTask = Task { [weak self] in
            try? await Task.sleep(for: Self.undoWindow)
            guard !Task.isCancelled else { return }
            self?.undoableBulkLog = nil
        }
    }
    
    private func clearUndoWindow() {
        undoExpiryTask?.cancel()
        undoExpiryTask = nil
        undoableBulkLog = nil
    }
    
    // MARK: - Notifications
    
    /// Same two steps as a single toggle: re-plan what is still due, then take the
    /// banners for fully logged slots off the lock screen.
    private func refreshNotifications(forSlotsOf doses: [PillDose]) {
        let slots = Set(doses.map(\.time))
        // Read from the refreshed list, so a slot the user had already half
        // logged is judged on what is actually taken now.
        let takenBySlot: [Date: [UUID]] = slots.reduce(into: [:]) { result, slot in
            result[slot] = allPills
                .filter { $0.time == slot && $0.isTaken }
                .map(\.medicationId)
        }
        
        Task { [notificationService, dbService] in
            await notificationService.rescheduleAll(using: dbService)
            for (slot, medicationIds) in takenBySlot where !medicationIds.isEmpty {
                await notificationService.clearDelivered(
                    settledMedicationIds: medicationIds,
                    scheduledTime: slot
                )
            }
        }
    }
    
    private func calculateWeeklyStats(with allCourses: [TreatmentCourse]) {
        let calendar = Calendar.current
        var percentages: [Double] = []
        var daysLabels: [String] = []
        
        var adherenceSum = 0.0
        var daysWithDoses = 0
        
        for i in (0..<7).reversed() {
            let date = calendar.date(byAdding: .day, value: -i, to: Date()) ?? Date()
            
            daysLabels.append(Self.weekdayFormatter.string(from: date))
            
            // Reuse the cached course list here too, to avoid a query per day.
            let dailyPills = dbService.fetchPills(for: date, preFetchedCourses: allCourses)
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
    }
}
