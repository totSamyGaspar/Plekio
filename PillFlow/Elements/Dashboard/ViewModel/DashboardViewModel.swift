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
    private var cancellables = Set<AnyCancellable>()
    
    init(dbService: DatabaseServiceProtocol) {
        self.dbService = dbService
        fetchData()
        
        NotificationCenter.default.publisher(for: .databaseDidUpdate)
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.fetchData()
            }
            .store(in: &cancellables)
    }
    
    var weekDates: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }
    
    // Фильтруем данные для UI
    var morningPills: [PillDose] { allPills.filter { $0.period == .morning } }
    var noonPills: [PillDose] { allPills.filter { $0.period == .noon } }
    var eveningPills: [PillDose] { allPills.filter { $0.period == .evening } }
    
    var isEmpty: Bool { allPills.isEmpty }
    
    private func fetchData() {
        // 1. Загружаем все курсы один раз из базы данных
        let allCourses = dbService.fetchAllCourses()
        
        // 2. Передаем этот список для получения таблеток на выбранную дату (без повторного обращения к БД)
        allPills = dbService.fetchPills(for: selectedDate, preFetchedCourses: allCourses)
        
        // 3. Передаем этот же список в метод расчета статистики
        calculateWeeklyStats(with: allCourses)
    }
    
    // Логика нажатия на чекбокс
    func togglePill(id: UUID) {
        // Находим таблетку по ID карточки
        guard let pill = allPills.first(where: { $0.id == id }) else { return }
        
        // Говорим БД переключить статус
        dbService.togglePill(medicationId: pill.medicationId, scheduledTime: pill.time)
        
        // Перерисовываем UI
        fetchData()
    }
    
    func handlePushTap(medicationId: UUID, time: Date, completion: @escaping (PillDose?) -> Void) {
        // Переключаем календарь на день из пуша (это автоматически вызовет fetchData)
        selectedDate = time
        
        // Даем UI миллисекунду на перерисовку и загрузку данных из БД
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
            
            // Форматируем день недели (Fri, Sat...)
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            daysLabels.append(formatter.string(from: date))
            
            // Передаем кэшированный список курсов во вложенном цикле
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
