//
//  DatabaseService.swift
//  PillFlow
//
//  Created by Edward Gasparian on 02.05.2026.
//

//import Foundation
//import SwiftData
//
//@MainActor
//final class DatabaseService: DatabaseServiceProtocol {
//    
//    static let shared = DatabaseService()
//    
//    private var dailyPillsCache: [Date: [PillDose]] = [:]
//    
//    let container: ModelContainer
//    let context: ModelContext
//    
//    // MARK: - Init
//    
//    private init() {
//        do {
//            let schema = Schema([
//                TreatmentCourse.self, MedicationItem.self, DoseLog.self,
//            ])
//            let config = ModelConfiguration(
//                schema: schema,
//                isStoredInMemoryOnly: false
//            )
//            container = try ModelContainer(
//                for: schema,
//                configurations: [config]
//            )
//            context = container.mainContext
//        } catch {
//            fatalError("🚨 Ошибка инициализации SwiftData: \(error)")
//        }
//    }
//    
//    // MARK: - Save
//    
//    func saveCourse(
//        name: String,
//        startDate: Date,
//        endDate: Date,
//        drafts: [MedicationDraft]
//    ) {
//        let course = TreatmentCourse(
//            name: name,
//            startDate: startDate,
//            endDate: endDate
//        )
//        context.insert(course)
//        
//        for draft in drafts {
//            let med = MedicationItem(
//                id: draft.id,
//                name: draft.name,
//                formSystemImage: draft.formSystemImage,
//                dosage: draft.dosage,
//                timesOfDay: draft.timesOfDay,
//                frequencyDays: draft.frequencyDays,
//                medicationImageData: draft.medicationImageData,
//                stockCount: draft.stockCount,
//                lowStockThreshold: draft.lowStockThreshold
//            )
//            course.medications.append(med)
//        }
//        
//        try? context.save()
//        
//        NotificationCenter.default.post(name: .databaseDidUpdate, object: nil)
//    }
//    
//    // MARK: - Fetch
//    
//    func fetchPills(for date: Date, preFetchedCourses: [TreatmentCourse]? = nil) -> [PillDose] {
//        let calendar = Calendar.current
//        let targetDate = calendar.startOfDay(for: date)
//        
//        if let cachedPills = dailyPillsCache[targetDate] {
//            return cachedPills
//        }
//        
//        let courses: [TreatmentCourse]
//        if let preFetched = preFetchedCourses {
//            courses = preFetched
//        } else {
//            let descriptor = FetchDescriptor<TreatmentCourse>()
//            courses = (try? context.fetch(descriptor)) ?? []
//        }
//        
//        var dailyPills: [PillDose] = []
//        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: targetDate) else { return [] }
//        
//        for course in courses {
//            let courseStart = calendar.startOfDay(for: course.startDate)
//            let courseEnd = calendar.startOfDay(for: course.endDate)
//            
//            // 1. Попадает ли дата в рамки курса?
//            if targetDate >= courseStart && targetDate <= courseEnd {
//                
//                // ОПТИМИЗАЦИЯ: Считаем разницу в днях ОДИН раз для всего курса
//                let daysDifference = calendar.dateComponents([.day], from: courseStart, to: targetDate).day ?? 0
//                
//                for med in course.medications {
//                    // 2. Проверка частоты приема
//                    if daysDifference % Int(med.frequencyDays) == 0 {
//                        
//                        // ОПТИМИЗАЦИЯ: Достаем только те логи, которые относятся к "сегодняшнему" дню
//                        let todaysLogs = med.logs.filter { $0.scheduledTime >= targetDate && $0.scheduledTime < endOfDay }
//                        
//                        for time in med.timesOfDay {
//                            // Быстрое извлечение компонентов
//                            let hour = calendar.component(.hour, from: time)
//                            let minute = calendar.component(.minute, from: time)
//                            
//                            guard let scheduledDate = calendar.date(
//                                bySettingHour: hour,
//                                minute: minute,
//                                second: 0,
//                                of: targetDate
//                            ) else { continue }
//                            
//                            let period: DayPeriod = hour < 12 ? .morning : (hour < 17 ? .noon : .evening)
//                            
//                            // ОПТИМИЗАЦИЯ: Ищем лог только в отфильтрованном крошечном массиве сегодняшних логов
//                            let log = todaysLogs.first(where: {
//                                calendar.component(.hour, from: $0.scheduledTime) == hour &&
//                                calendar.component(.minute, from: $0.scheduledTime) == minute
//                            })
//                            
//                            dailyPills.append(
//                                PillDose(
//                                    medicationId: med.id,
//                                    name: med.name,
//                                    dosage: "\(med.dosage) pcs",
//                                    formSystemImage: med.formSystemImage,
//                                    time: scheduledDate,
//                                    period: period,
//                                    isTaken: log?.isTaken ?? false,
//                                    medicationImageData: med.medicationImageData,
//                                    stockCount: med.stockCount,
//                                    lowStockThreshold: med.lowStockThreshold
//                                )
//                            )
//                        }
//                    }
//                }
//            }
//        }
//        
//        let sortedPills = dailyPills.sorted(by: { $0.time < $1.time })
//        
//        // 2. СОХРАНЯЕМ В КЕШ перед тем как вернуть
//        dailyPillsCache[targetDate] = sortedPills
//        return sortedPills
//    }
//    
//    // MARK: - Refill
//    
//    func refillStock(for medication: MedicationItem, amount: Int) {
//        medication.stockCount += amount
//        
//        try? context.save()
//        
//        NotificationCenter.default.post(name: .databaseDidUpdate, object: nil)
//    }
//    
//    // MARK: - Update meds
//    
//    func updateMedication(_ medication: MedicationItem, with draft: MedicationDraft) {
//        medication.name = draft.name
//        medication.formSystemImage = draft.formSystemImage
//        medication.dosage = draft.dosage
//        medication.stockCount = draft.stockCount
//        medication.lowStockThreshold = draft.lowStockThreshold
//        medication.frequencyDays = draft.frequencyDays
//        medication.timesOfDay = draft.timesOfDay
//        medication.medicationImageData = draft.medicationImageData
//        
//        try? context.save()
//
//        NotificationCenter.default.post(name: .databaseDidUpdate, object: nil)
//    }
//    
//    // MARK: - Toggle take
//    
//    func togglePill(medicationId: UUID, scheduledTime: Date) {
//        let descriptor = FetchDescriptor<MedicationItem>(
//            predicate: #Predicate { $0.id == medicationId }
//        )
//        guard let med = try? context.fetch(descriptor).first else { return }
//        
//        let calendar = Calendar.current
//        
//        if let existingLog = med.logs.first(where: {
//            calendar.isDate($0.scheduledTime, inSameDayAs: scheduledTime)
//            && calendar.component(.hour, from: $0.scheduledTime)
//            == calendar.component(.hour, from: scheduledTime)
//            && calendar.component(.minute, from: $0.scheduledTime)
//            == calendar.component(.minute, from: scheduledTime)
//        }) {
//            existingLog.isTaken.toggle()
//            existingLog.actualTakeTime = existingLog.isTaken ? Date() : nil
//            if existingLog.isTaken {
//                med.stockCount -= med.dosage
//            } else {
//                med.stockCount += med.dosage
//            }
//        } else {
//            let newLog = DoseLog(scheduledTime: scheduledTime, isTaken: true)
//            newLog.actualTakeTime = Date()
//            med.logs.append(newLog)
//            med.stockCount -= med.dosage
//        }
//        try? context.save()
//        NotificationCenter.default.post(name: .databaseDidUpdate, object: nil)
//    }
//    
//    // MARK: - Управление курсами
//    
//    func fetchAllCourses() -> [TreatmentCourse] {
//        let descriptor = FetchDescriptor<TreatmentCourse>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
//        return (try? context.fetch(descriptor)) ?? []
//    }
//    
//    func deleteCourse(_ course: TreatmentCourse) {
//        context.delete(course)
//        try? context.save()
//        
//        NotificationCenter.default.post(name: .databaseDidUpdate, object: nil)
//    }
//    
//    func deleteMedication(_ medication: MedicationItem) {
//        context.delete(medication)
//        try? context.save()
//        
//        NotificationCenter.default.post(name: .databaseDidUpdate, object: nil)
//    }
//    
//    func updateCourseDetails(course: TreatmentCourse, name: String, startDate: Date, endDate: Date) {
//        course.name = name
//        course.startDate = startDate
//        course.endDate = endDate
//        try? context.save()
//        NotificationCenter.default.post(name: .databaseDidUpdate, object: nil)
//    }
//    
//    func addMedication(draft: MedicationDraft, to course: TreatmentCourse) {
//        let med = MedicationItem(
//            id: draft.id,
//            name: draft.name,
//            formSystemImage: draft.formSystemImage,
//            dosage: draft.dosage,
//            timesOfDay: draft.timesOfDay,
//            frequencyDays: draft.frequencyDays,
//            medicationImageData: draft.medicationImageData,
//            stockCount: draft.stockCount,
//            lowStockThreshold: draft.lowStockThreshold
//        )
//        course.medications.append(med)
//        try? context.save()
//        NotificationCenter.default.post(name: .databaseDidUpdate, object: nil)
//    }
//}
//
//extension Notification.Name {
//    static let databaseDidUpdate = Notification.Name("databaseDidUpdate")
//}
//
//  DatabaseService.swift
//  PillFlow
//
//  Created by Edward Gasparian on 02.05.2026.
//

import Foundation
import SwiftData

@MainActor
final class DatabaseService: DatabaseServiceProtocol {
    
    static let shared = DatabaseService()
    
    // КЕШ: Ключ — начало дня (startOfDay), Значение — подготовленный массив таблеток
    private var dailyPillsCache: [Date: [PillDose]] = [:]
    
    let container: ModelContainer
    let context: ModelContext
    
    // MARK: - Init
    
    private init() {
        do {
            let schema = Schema([
                TreatmentCourse.self, MedicationItem.self, DoseLog.self,
            ])
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            container = try ModelContainer(
                for: schema,
                configurations: [config]
            )
            context = container.mainContext
        } catch {
            fatalError("🚨 Ошибка инициализации SwiftData: \(error)")
        }
    }
    
    // MARK: - Save
    
    func saveCourse(
        name: String,
        startDate: Date,
        endDate: Date,
        drafts: [MedicationDraft]
    ) {
        // Инвалидация кеша
        dailyPillsCache.removeAll()
        
        let course = TreatmentCourse(
            name: name,
            startDate: startDate,
            endDate: endDate
        )
        context.insert(course)
        
        for draft in drafts {
            let med = MedicationItem(
                id: draft.id,
                name: draft.name,
                formSystemImage: draft.formSystemImage,
                dosage: draft.dosage,
                timesOfDay: draft.timesOfDay,
                frequencyDays: draft.frequencyDays,
                medicationImageData: draft.medicationImageData,
                stockCount: draft.stockCount,
                lowStockThreshold: draft.lowStockThreshold
            )
            course.medications.append(med)
        }
        
        try? context.save()
        NotificationCenter.default.post(name: .databaseDidUpdate, object: nil)
    }
    
    // MARK: - Fetch
    
    func fetchPills(for date: Date, preFetchedCourses: [TreatmentCourse]? = nil) -> [PillDose] {
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: date)
        
        // 1. ПРОВЕРЯЕМ КЕШ: если данные для этого дня уже считались, отдаем мгновенно
        if let cachedPills = dailyPillsCache[targetDate] {
            return cachedPills
        }
        
        let courses: [TreatmentCourse]
        if let preFetched = preFetchedCourses {
            courses = preFetched
        } else {
            let descriptor = FetchDescriptor<TreatmentCourse>()
            courses = (try? context.fetch(descriptor)) ?? []
        }
        
        var dailyPills: [PillDose] = []
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: targetDate) else { return [] }
        
        for course in courses {
            let courseStart = calendar.startOfDay(for: course.startDate)
            let courseEnd = calendar.startOfDay(for: course.endDate)
            
            // Попадает ли выбранная дата в рамки курса?
            if targetDate >= courseStart && targetDate <= courseEnd {
                
                // ОПТИМИЗАЦИЯ: Считаем разницу в днях ОДИН раз для всего курса, а не для каждого препарата
                let daysDifference = calendar.dateComponents([.day], from: courseStart, to: targetDate).day ?? 0
                
                for med in course.medications {
                    // Магия интервалов
                    if daysDifference % Int(med.frequencyDays) == 0 {
                        
                        // ОПТИМИЗАЦИЯ: Фильтруем логи только для сегодняшнего дня ЗАРАНЕЕ
                        let todaysLogs = med.logs.filter { $0.scheduledTime >= targetDate && $0.scheduledTime < endOfDay }
                        
                        for time in med.timesOfDay {
                            // Быстрое извлечение компонентов часа и минуты
                            let hour = calendar.component(.hour, from: time)
                            let minute = calendar.component(.minute, from: time)
                            
                            guard let scheduledDate = calendar.date(
                                bySettingHour: hour,
                                minute: minute,
                                second: 0,
                                of: targetDate
                            ) else { continue }
                            
                            let period: DayPeriod = hour < 12 ? .morning : (hour < 17 ? .noon : .evening)
                            
                            // ОПТИМИЗАЦИЯ: Ищем лог в отфильтрованном крошечном массиве сегодняшних логов
                            let log = todaysLogs.first(where: {
                                calendar.component(.hour, from: $0.scheduledTime) == hour &&
                                calendar.component(.minute, from: $0.scheduledTime) == minute
                            })
                            
                            dailyPills.append(
                                PillDose(
                                    medicationId: med.id,
                                    name: med.name,
                                    dosage: "\(med.dosage) pcs",
                                    formSystemImage: med.formSystemImage,
                                    time: scheduledDate,
                                    period: period,
                                    isTaken: log?.isTaken ?? false,
                                    medicationImageData: med.medicationImageData,
                                    stockCount: med.stockCount,
                                    lowStockThreshold: med.lowStockThreshold
                                )
                            )
                        }
                    }
                }
            }
        }
        
        let sortedPills = dailyPills.sorted(by: { $0.time < $1.time })
        
        // 2. СОХРАНЯЕМ В КЕШ: перед возвратом записываем результат
        dailyPillsCache[targetDate] = sortedPills
        return sortedPills
    }
    
    // MARK: - Refill
    
    func refillStock(for medication: MedicationItem, amount: Int) {
        
//        dailyPillsCache.removeAll()
        
        medication.stockCount += amount
        try? context.save()
        NotificationCenter.default.post(name: .databaseDidUpdate, object: nil)
    }
    
    // MARK: - Update meds
    
    func updateMedication(_ medication: MedicationItem, with draft: MedicationDraft) {
        dailyPillsCache.removeAll()
        
        medication.name = draft.name
        medication.formSystemImage = draft.formSystemImage
        medication.dosage = draft.dosage
        medication.stockCount = draft.stockCount
        medication.lowStockThreshold = draft.lowStockThreshold
        medication.frequencyDays = draft.frequencyDays
        medication.timesOfDay = draft.timesOfDay
        medication.medicationImageData = draft.medicationImageData
        
        try? context.save()
        NotificationCenter.default.post(name: .databaseDidUpdate, object: nil)
    }
    
    // MARK: - Toggle take
    
    func togglePill(medicationId: UUID, scheduledTime: Date) {
        let targetDay = Calendar.current.startOfDay(for: scheduledTime)
        dailyPillsCache.removeValue(forKey: targetDay)
        
        let descriptor = FetchDescriptor<MedicationItem>(
            predicate: #Predicate { $0.id == medicationId }
        )
        guard let med = try? context.fetch(descriptor).first else { return }
        
        let calendar = Calendar.current
        
        if let existingLog = med.logs.first(where: {
            calendar.isDate($0.scheduledTime, inSameDayAs: scheduledTime)
            && calendar.component(.hour, from: $0.scheduledTime)
            == calendar.component(.hour, from: scheduledTime)
            && calendar.component(.minute, from: $0.scheduledTime)
            == calendar.component(.minute, from: scheduledTime)
        }) {
            existingLog.isTaken.toggle()
            existingLog.actualTakeTime = existingLog.isTaken ? Date() : nil
            if existingLog.isTaken {
                med.stockCount -= med.dosage
            } else {
                med.stockCount += med.dosage
            }
        } else {
            let newLog = DoseLog(scheduledTime: scheduledTime, isTaken: true)
            newLog.actualTakeTime = Date()
            med.logs.append(newLog)
            med.stockCount -= med.dosage
        }
        try? context.save()
        NotificationCenter.default.post(name: .databaseDidUpdate, object: nil)
    }
    
    // MARK: - Управление курсами
    
    func fetchAllCourses() -> [TreatmentCourse] {
        let descriptor = FetchDescriptor<TreatmentCourse>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }
    
    func deleteCourse(_ course: TreatmentCourse) {
        dailyPillsCache.removeAll()
        
        context.delete(course)
        try? context.save()
        NotificationCenter.default.post(name: .databaseDidUpdate, object: nil)
    }
    
    func deleteMedication(_ medication: MedicationItem) {
        dailyPillsCache.removeAll()
        
        context.delete(medication)
        try? context.save()
        NotificationCenter.default.post(name: .databaseDidUpdate, object: nil)
    }
    
    func updateCourseDetails(course: TreatmentCourse, name: String, startDate: Date, endDate: Date) {
        dailyPillsCache.removeAll()
        
        course.name = name
        course.startDate = startDate
        course.endDate = endDate
        try? context.save()
        NotificationCenter.default.post(name: .databaseDidUpdate, object: nil)
    }
    
    func addMedication(draft: MedicationDraft, to course: TreatmentCourse) {
        dailyPillsCache.removeAll()
        
        let med = MedicationItem(
            id: draft.id,
            name: draft.name,
            formSystemImage: draft.formSystemImage,
            dosage: draft.dosage,
            timesOfDay: draft.timesOfDay,
            frequencyDays: draft.frequencyDays,
            medicationImageData: draft.medicationImageData,
            stockCount: draft.stockCount,
            lowStockThreshold: draft.lowStockThreshold
        )
        course.medications.append(med)
        try? context.save()
        NotificationCenter.default.post(name: .databaseDidUpdate, object: nil)
    }
}

extension Notification.Name {
    static let databaseDidUpdate = Notification.Name("databaseDidUpdate")
}
