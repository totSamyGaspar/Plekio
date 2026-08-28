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

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter
    }()

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

        notificationService.rescheduleAll(using: dbService)

        fetchData()

        if !wasTaken {
            let takenAtSlot = allPills
                .filter { $0.time == pill.time && $0.isTaken }
                .map(\.medicationId)
            notificationService.clearDelivered(
                takenMedicationIds: takenAtSlot,
                scheduledTime: pill.time
            )
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
