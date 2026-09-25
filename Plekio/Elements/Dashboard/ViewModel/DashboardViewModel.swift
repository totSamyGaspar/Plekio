//
//  DashboardViewModel.swift
//  Plekio
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
    
    /// Reads only: what is due on a day, and the courses behind it.
    private let dbService: any CourseStoring & DoseStoring
    /// Every write about a dose, together with its reminder side effects.
    private let doseLogging: DoseLoggingUseCaseProtocol
    private var cancellables = Set<AnyCancellable>()
    
    /// Closes the undo window on its own. Held so a second "Log all" replaces the
    /// first countdown instead of racing it.
    private var undoExpiryTask: Task<Void, Never>?
    
    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter
    }()
    
    // MARK: - Init
    
    init(dbService: any CourseStoring & DoseStoring, doseLogging: DoseLoggingUseCaseProtocol) {
        self.dbService = dbService
        self.doseLogging = doseLogging
        fetchData()
        
        // Doses as well as courses: this screen is where a dose is logged.
        NotificationCenter.default.publisher(forDatabaseChanges: [.courses, .doses])
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.fetchData()
            }
            .store(in: &cancellables)
    }
    
    /// Builds the default use case from the two services. Kept so tests and
    /// previews can keep constructing the screen from mocks of those two.
    convenience init(dbService: any CourseStoring & DoseStoring, notificationService: NotificationServiceProtocol) {
        self.init(
            dbService: dbService,
            doseLogging: DoseLoggingUseCase(dbService: dbService, notificationService: notificationService)
        )
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
    //
    // Each of these says what the user did and hands it to the use case. The
    // write, the reminder rebuild and the lock-screen cleanup are its business;
    // what is left here is the screen: refresh it, and run the undo banner.

    func togglePill(id: PillDose.ID) {
        guard let pill = allPills.first(where: { $0.id == id }),
              AppErrorPresenter.shared.attempt({ try doseLogging.toggle(pill) }) != nil
        else { return }

        fetchData()
    }

    /// "Log all": one write per slot, one reminder rebuild, and an undo banner
    /// offering back exactly what was written.
    func logDoses(_ doses: [PillDose]) {
        guard let outcome = AppErrorPresenter.shared.attempt({ try doseLogging.markTaken(doses) }),
              outcome.didWrite
        else { return }

        fetchData()
        startUndoWindow(with: outcome.written)
    }

    /// The sheet's "Skip" / "Skip All".
    func skipDoses(_ doses: [PillDose]) {
        guard let outcome = AppErrorPresenter.shared.attempt({ try doseLogging.markSkipped(doses) }),
              outcome.didWrite
        else { return }

        fetchData()
    }

    /// Puts back exactly what the last "Log all" wrote.
    func undoBulkLog() {
        guard let log = undoableBulkLog else { return }
        clearUndoWindow()

        guard let outcome = AppErrorPresenter.shared.attempt({ try doseLogging.revertTaken(log.doses) }),
              outcome.didWrite
        else { return }

        fetchData()
    }

    func dismissUndo() {
        clearUndoWindow()
    }

    // MARK: - Undo window
    
    private func startUndoWindow(with doses: [PillDose]) {
        undoExpiryTask?.cancel()
        undoableBulkLog = BulkDoseLog(doses: doses)
        
        undoExpiryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(BulkDoseLog.window))
            guard !Task.isCancelled else { return }
            self?.undoableBulkLog = nil
        }
    }
    
    private func clearUndoWindow() {
        undoExpiryTask?.cancel()
        undoExpiryTask = nil
        undoableBulkLog = nil
    }
    
    // MARK: - Weekly statistics

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
