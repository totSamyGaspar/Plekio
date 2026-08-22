//
//  StatisticsViewModel.swift
//  PillFlow
//
//  Created by Edward Gasparian on 06.05.2026.
//

import SwiftUI
import Combine


@MainActor
final class StatisticsViewModel: StatisticsViewModelProtocol {
    @Published var takenCount: Int = 0
    @Published var totalCount: Int = 0
    @Published var streakDays: Int = 0
    @Published var lowStockItems: [MedicationItem] = []
    
    private let dbService: DatabaseServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(takenCount) / Double(totalCount)
    }
    
    init(dbService: DatabaseServiceProtocol) {
        self.dbService = dbService
        loadStats()

        NotificationCenter.default.publisher(for: .databaseDidUpdate)
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.loadStats() }
            .store(in: &cancellables)
    }
    
    func loadStats() {
        let allCourses = dbService.fetchAllCourses()
        
        // 1. Today's progress (fetchPills is used since this is today's schedule)
        let todaysPills = dbService.fetchPills(for: Date(), preFetchedCourses: allCourses)
        self.totalCount = todaysPills.count
        self.takenCount = todaysPills.filter { $0.isTaken }.count

        // 2. Find medications that are running low on stock
        var lowStock: [MedicationItem] = []
        for course in allCourses {
            for med in course.medications where med.stockCount <= med.lowStockThreshold {
                lowStock.append(med)
            }
        }
        self.lowStockItems = lowStock

        // 3. Optimized streak calculation
        self.streakDays = calculateOptimizedStreak(courses: allCourses)
    }
    
    // MARK: - Optimized Streak Calculation
    private func calculateOptimizedStreak(courses: [TreatmentCourse]) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        guard let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today) else { return 0 }

        // Maps each day to (taken, total scheduled) counts
        var dailyStats: [Date: (taken: Int, total: Int)] = [:]

        // Single pass over all logs to build the daily stats
        for course in courses {
            for med in course.medications {
                // Only the last 30 days, excluding today
                let recentLogs = med.logs.filter { $0.scheduledTime >= thirtyDaysAgo && $0.scheduledTime < today }

                for log in recentLogs {
                    let logDay = calendar.startOfDay(for: log.scheduledTime)

                    if dailyStats[logDay] == nil {
                        dailyStats[logDay] = (taken: 0, total: 0)
                    }

                    dailyStats[logDay]!.total += 1

                    if log.isTaken {
                        dailyStats[logDay]!.taken += 1
                    }
                }
            }
        }

        var currentStreak = 0

        // Walk backwards from yesterday, up to 30 days
        for i in 1...30 {
            let targetDate = calendar.date(byAdding: .day, value: -i, to: today)!

            // Stop the streak on any day with no scheduled pills
            if let stats = dailyStats[targetDate], stats.total > 0 {
                let percent = Double(stats.taken) / Double(stats.total)
                
                if percent >= 0.9 {
                    currentStreak += 1
                } else {
                    break
                }
            } else { break }
        }
        return currentStreak
    }
    
    // MARK: - Refill
    func refill(medication: MedicationItem, amount: Int) {
        dbService.refillStock(for: medication, amount: amount)
        
        loadStats()
    }
}
