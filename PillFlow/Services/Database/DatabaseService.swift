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

    // Cache: key is the start of day, value is the prepared array of pills
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
            fatalError("🚨 Failed to initialize SwiftData: \(error)")
        }
    }

    // Separate initializer for unit tests. `DatabaseService.shared` is a
    // disk-backed singleton, so it can't be used in tests (it would collide
    // with real app data and across test runs). This spins up an independent
    // in-memory ModelContainer with the same schema, so tests exercise the
    // real DatabaseService logic (fetchPills, togglePill, etc.) without
    // touching disk. Not used by production code.
    init(inMemoryForTesting: Bool) {
        do {
            let schema = Schema([
                TreatmentCourse.self, MedicationItem.self, DoseLog.self,
            ])
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
            container = try ModelContainer(
                for: schema,
                configurations: [config]
            )
            context = container.mainContext
        } catch {
            fatalError("🚨 Failed to initialize test (in-memory) SwiftData: \(error)")
        }
    }

    // MARK: - Save

    func saveCourse(
        name: String,
        startDate: Date,
        endDate: Date,
        drafts: [MedicationDraft]
    ) {
        // Invalidate cache
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
                stockCount: draft.stockCount,
                lowStockThreshold: draft.lowStockThreshold
            )
            course.medications.append(med)
            // Photo (if selected) is written to disk separately — the model no longer stores a blob.
            if let imageData = draft.medicationImageData {
                ImageCache.shared.saveToDisk(imageData, for: med.id)
            }
        }

        try? context.save()
        NotificationCenter.default.post(name: .databaseDidUpdate, object: nil)
    }

    // MARK: - Fetch

    func fetchPills(for date: Date, preFetchedCourses: [TreatmentCourse]? = nil) -> [PillDose] {
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: date)

        // 1. Check cache: if this day's data was already computed, return it immediately
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

            // Does the target date fall within the course's date range?
            if targetDate >= courseStart && targetDate <= courseEnd {

                // Optimization: compute the day difference once per course, not per medication
                let daysDifference = calendar.dateComponents([.day], from: courseStart, to: targetDate).day ?? 0

                for med in course.medications {
                    // Is this medication due today, based on its dosing interval?
                    if daysDifference % Int(med.frequencyDays) == 0 {

                        // Optimization: pre-filter logs to just today's entries
                        let todaysLogs = med.logs.filter { $0.scheduledTime >= targetDate && $0.scheduledTime < endOfDay }

                        for time in med.timesOfDay {
                            let hour = calendar.component(.hour, from: time)
                            let minute = calendar.component(.minute, from: time)

                            guard let scheduledDate = calendar.date(
                                bySettingHour: hour,
                                minute: minute,
                                second: 0,
                                of: targetDate
                            ) else { continue }

                            let period: DayPeriod = hour < 12 ? .morning : (hour < 17 ? .noon : .evening)

                            // Optimization: search within the small pre-filtered array of today's logs
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

        // 2. Save to cache before returning
        dailyPillsCache[targetDate] = sortedPills
        return sortedPills
    }

    // MARK: - Refill

    func refillStock(for medication: MedicationItem, amount: Int) {
        // Invalidate the cache so already-cached PillDose entries (today and other
        // open days) don't keep showing the stale stockCount / "LOW" badge after a refill.
        dailyPillsCache.removeAll()

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

        // Explicitly handle the photo: save new/kept data, or delete the file if the
        // user removed it via removeImage(). draft.medicationImageData is populated
        // with the existing bytes when entering edit mode (see
        // AddMedicationView.init(editingMedication:)), so saving without changing the
        // photo can't be mistaken for deleting it.
        if let imageData = draft.medicationImageData {
            ImageCache.shared.saveToDisk(imageData, for: medication.id)
        } else {
            ImageCache.shared.deleteFromDisk(for: medication.id)
        }

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

    // MARK: - Course Management

    func fetchAllCourses() -> [TreatmentCourse] {
        let descriptor = FetchDescriptor<TreatmentCourse>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func deleteCourse(_ course: TreatmentCourse) {
        dailyPillsCache.removeAll()

        // The course cascade-deletes all its MedicationItem records (see
        // deleteRule: .cascade on TreatmentCourse.medications), but photo files
        // on disk aren't removed automatically — clean them up here, or they'll
        // be left orphaned.
        for med in course.medications {
            ImageCache.shared.deleteFromDisk(for: med.id)
        }

        context.delete(course)
        try? context.save()
        NotificationCenter.default.post(name: .databaseDidUpdate, object: nil)
    }

    func deleteMedication(_ medication: MedicationItem) {
        dailyPillsCache.removeAll()

        // Also remove the photo file from disk, if any, so it isn't left orphaned.
        ImageCache.shared.deleteFromDisk(for: medication.id)

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
            stockCount: draft.stockCount,
            lowStockThreshold: draft.lowStockThreshold
        )
        course.medications.append(med)
        if let imageData = draft.medicationImageData {
            ImageCache.shared.saveToDisk(imageData, for: med.id)
        }
        try? context.save()
        NotificationCenter.default.post(name: .databaseDidUpdate, object: nil)
    }
}

extension Notification.Name {
    static let databaseDidUpdate = Notification.Name("databaseDidUpdate")
}
