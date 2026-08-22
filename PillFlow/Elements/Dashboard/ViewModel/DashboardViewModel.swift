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
        didSet { fetchData() }
    }
    @Published private var allPills: [PillDose] = []
    @Published var weeklyPercentages: [Double] = Array(repeating: 0.0, count: 7)
    @Published var weeklyDays: [String] = []
    @Published var recentAverage: Int = 0
    
    
    private let dbService: DatabaseServiceProtocol
    private let notificationService: NotificationServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(dbService: DatabaseServiceProtocol, notificationService: NotificationServiceProtocol) {
        self.dbService = dbService
        self.notificationService = notificationService
        fetchData()
        
        NotificationCenter.default.publisher(for: .databaseDidUpdate)
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
        // Load all courses once from the database...
        let allCourses = dbService.fetchAllCourses()

        // ...and reuse that list for both the selected date's pills...
        allPills = dbService.fetchPills(for: selectedDate, preFetchedCourses: allCourses)

        // ...and the weekly stats calculation, avoiding repeated DB queries.
        calculateWeeklyStats(with: allCourses)
    }

    // MARK: - Actions

    func togglePill(id: UUID) {
        guard let pill = allPills.first(where: { $0.id == id }) else { return }

        dbService.togglePill(medicationId: pill.medicationId, scheduledTime: pill.time)

        // Marking a dose taken must also keep pending push notifications in
        // sync (otherwise a reminder can still fire after the dose was
        // logged). Full reset + reschedule, same approach used elsewhere
        // (CourseDetailViewModel, NewTreatmentViewModel); scheduleNotifications
        // itself skips slots already marked taken.
        notificationService.removeAllPending()
        let activeCourses = dbService.fetchAllCourses().filter { $0.endDate >= Date() }
        notificationService.scheduleNotifications(activeCourses: activeCourses)

        fetchData()
    }

    func handlePushTap(medicationId: UUID, time: Date, completion: @escaping (PillDose?) -> Void) {
        // Setting selectedDate triggers fetchData via its didSet.
        selectedDate = time

        // Give the UI a moment to redraw and finish loading before reading allPills.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let pill = self.allPills.first(where: { $0.medicationId == medicationId })
            completion(pill)
        }
    }

    private func calculateWeeklyStats(with allCourses: [TreatmentCourse]) {
        let calendar = Calendar.current
        var percentages: [Double] = []
        var daysLabels: [String] = []
        var totalAverage = 0.0
        
        for i in (0..<7).reversed() {
            let date = calendar.date(byAdding: .day, value: -i, to: Date()) ?? Date()
            
            // Format the weekday label (Fri, Sat...)
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            daysLabels.append(formatter.string(from: date))

            // Reuse the cached course list here too, to avoid a query per day.
            let dailyPills = dbService.fetchPills(for: date, preFetchedCourses: allCourses)
            if dailyPills.isEmpty {
                percentages.append(0.0)
            } else {
                let taken = dailyPills.filter { $0.isTaken }.count
                let percent = Double(taken) / Double(dailyPills.count)
                percentages.append(percent)
                totalAverage += percent
            }
        }
        
        self.weeklyPercentages = percentages
        self.weeklyDays = daysLabels
        self.recentAverage = Int((totalAverage / 7.0) * 100)
    }
}
