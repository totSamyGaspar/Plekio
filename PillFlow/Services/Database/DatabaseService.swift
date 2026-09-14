//
//  DatabaseService.swift
//  PillFlow
//
//  Created by Edward Gasparian on 02.05.2026.
//

import Foundation
import OSLog
import SwiftData

@MainActor
final class DatabaseService: DatabaseServiceProtocol {

    static let shared = DatabaseService()

    private var dailyPillsCache: [Date: [PillDose]] = [:]

    let container: ModelContainer
    let context: ModelContext

    /// Set when the on-disk store could not be opened and the app fell back to an
    /// in-memory container. Nothing survives a restart in that mode, so the UI has
    /// to tell the user.
    private(set) var storageFailure: Error?

    /// Single source of truth for the schema. It used to be duplicated across two
    /// initializers, so a model could end up registered in only one of them.
    private static func makeSchema() -> Schema {
        Schema([
            TreatmentCourse.self, MedicationItem.self, DoseLog.self, DiaryEntry.self,
            BloodPressureReading.self,
        ])
    }

    // MARK: - Init

    private init() {
        let schema = Self.makeSchema()

        do {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Crashing on launch is the worst outcome: the user just sees the app die
            // with no idea what happened to their history. Fall back to memory and
            // surface storageFailure instead.
            AppLog.storage.critical("Failed to open the on-disk store: \(error.localizedDescription, privacy: .public)")

            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            guard let memoryContainer = try? ModelContainer(for: schema, configurations: [fallback]) else {
                // Not even memory works — there is nothing left to fall back to.
                fatalError("🚨 SwiftData is unavailable even in memory: \(error)")
            }

            container = memoryContainer
            storageFailure = error
        }

        context = container.mainContext

        if storageFailure != nil {
            AppErrorPresenter.shared.message = String(
                localized: "Storage on this device is unavailable. The app is running in temporary mode — entries will not survive a restart."
            )
        }
    }

    /// Test-only entry point. `shared` is disk-backed, so tests using it would
    /// collide with real app data and with each other. This builds an independent
    /// in-memory container on the same schema, exercising the real logic without
    /// touching disk.
    init(inMemoryForTesting: Bool) {
        do {
            let schema = Self.makeSchema()
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            container = try ModelContainer(for: schema, configurations: [config])
            context = container.mainContext
        } catch {
            fatalError("🚨 Failed to initialize test (in-memory) SwiftData: \(error)")
        }
    }

    // MARK: - Commit

    /// The only place the context is saved.
    ///
    /// Mutations used to end in `try? context.save()` and announce success
    /// unconditionally, so a failed write still told the UI everything was fine —
    /// silent data loss in a medication history. On failure the context is rolled
    /// back, so memory never holds state that isn't on disk, and the error is
    /// rethrown.
    ///
    /// `changes` has no default on purpose. Every mutation has to say what it
    /// touched, and a new one cannot quietly inherit somebody else's answer.
    private func commit(_ changes: Set<DatabaseChange>) throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            dailyPillsCache.removeAll()
            throw DatabaseError.saveFailed(underlying: error)
        }

        // Invalidated here rather than at the top of each mutating method. Every
        // write goes through this function and every write invalidates the cache,
        // so the two belong together: the old arrangement was ten call sites that
        // each had to remember, and forgetting one is a stale dose on screen.
        dailyPillsCache.removeAll()

        NotificationCenter.default.post(
            name: .databaseDidChange,
            object: nil,
            userInfo: [DatabaseChange.userInfoKey: changes]
        )
    }

    // MARK: - Save

    func saveCourse(
        name: String,
        startDate: Date,
        endDate: Date,
        drafts: [MedicationDraft]
    ) throws {
        let course = TreatmentCourse(
            name: name,
            startDate: startDate,
            endDate: endDate
        )
        context.insert(course)

        // Collected here and written only after a successful commit: a rollback
        // must not leave files on disk for medications that no longer exist.
        var pendingPhotos: [(UUID, Data)] = []

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
            if let imageData = draft.medicationImageData {
                pendingPhotos.append((med.id, imageData))
            }
        }

        try commit([.courses])

        for (id, data) in pendingPhotos {
            ImageCache.shared.saveToDisk(data, for: id)
        }
    }

    /// Starts a finished course over: a brand-new course with fresh dates and a
    /// fresh copy of every medication.
    ///
    /// The medications get new ids rather than being moved, so the original stays
    /// in the history with its own dose logs intact — repeating a course must not
    /// rewrite what actually happened last time. Photos live on disk keyed by the
    /// medication id (see ImageCache), so each one is copied across to the new id.
    func duplicateCourse(_ course: TreatmentCourse, startDate: Date, endDate: Date) throws {
        let newCourse = TreatmentCourse(
            name: course.name,
            startDate: startDate,
            endDate: endDate,
            // The chain's first course, so repeating a copy of a copy is still
            // recognised as the same treatment running again.
            repeatedFromId: course.repeatLineageId
        )
        context.insert(newCourse)

        // Same reason as in saveCourse: files are written only once the write
        // has actually committed.
        var pendingPhotos: [(UUID, Data)] = []

        for source in course.medications {
            let copyId = UUID()
            let med = MedicationItem(
                id: copyId,
                name: source.name,
                formSystemImage: source.formSystemImage,
                dosage: source.dosage,
                timesOfDay: source.timesOfDay,
                frequencyDays: source.frequencyDays,
                stockCount: source.stockCount,
                lowStockThreshold: source.lowStockThreshold
            )
            newCourse.medications.append(med)

            if let imageData = ImageCache.shared.loadDataFromDisk(for: source.id) {
                pendingPhotos.append((copyId, imageData))
            }
        }

        try commit([.courses])

        for (id, data) in pendingPhotos {
            ImageCache.shared.saveToDisk(data, for: id)
        }
    }

    // MARK: - Fetch

    func fetchPills(for date: Date, preFetchedCourses: [TreatmentCourse]? = nil) -> [PillDose] {
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: date)

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

            if targetDate >= courseStart && targetDate <= courseEnd {

                let daysDifference = calendar.dateComponents([.day], from: courseStart, to: targetDate).day ?? 0

                for med in course.medications {
                    // The interval is a divisor: zero would trap. The UI can't produce
                    // it, but imported or migrated data can.
                    guard med.frequencyDays > 0 else { continue }

                    if daysDifference % med.frequencyDays == 0 {

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

                            let log = todaysLogs.first(where: {
                                calendar.component(.hour, from: $0.scheduledTime) == hour &&
                                calendar.component(.minute, from: $0.scheduledTime) == minute
                            })

                            dailyPills.append(
                                PillDose(
                                    medicationId: med.id,
                                    name: med.name,
                                    dosage: med.dosage,
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

        dailyPillsCache[targetDate] = sortedPills
        return sortedPills
    }

    // MARK: - Refill

    func refillStock(for medication: MedicationItem, amount: Int) throws {
        medication.stockCount += amount
        try commit([.courses])
    }

    // MARK: - Update meds

    func updateMedication(_ medication: MedicationItem, with draft: MedicationDraft) throws {
        // Captured before assigning: dose logs are keyed by hour+minute, so they
        // have to be remapped once the times move.
        let previousTimes = medication.timesOfDay

        medication.name = draft.name
        medication.formSystemImage = draft.formSystemImage
        medication.dosage = draft.dosage
        medication.stockCount = draft.stockCount
        medication.lowStockThreshold = draft.lowStockThreshold
        medication.frequencyDays = draft.frequencyDays
        medication.timesOfDay = draft.timesOfDay

        remapLogs(of: medication, from: previousTimes, to: draft.timesOfDay)

        // Disk is touched only when the user actually changed the photo, and only
        // after a successful commit — a rollback must not leave the record without
        // its file. An untouched draft is left alone: it can be empty simply because
        // the preload hasn't finished, and treating that as a deletion erased photos
        // on an unrelated edit (a rename). Same contract as updateDiaryEntry.
        let photoModified = draft.photoModified
        let newImageData = draft.medicationImageData
        let medicationId = medication.id

        try commit([.courses])

        guard photoModified else { return }

        if let newImageData {
            ImageCache.shared.saveToDisk(newImageData, for: medicationId)
        } else {
            ImageCache.shared.deleteFromDisk(for: medicationId)
        }
    }

    /// Moves existing dose logs onto the new times by position — the first dose of
    /// the day stays the first.
    ///
    /// `DoseLog` is looked up by hour+minute (see `togglePill` and `fetchPills`), so
    /// moving a dose from 8:00 to 9:00 used to orphan its logs: the day looked
    /// unlogged even though stock had already been deducted.
    ///
    /// Logs of removed slots stay in the store as history. Statistics are computed
    /// from the schedule, so they no longer affect any number.
    private func remapLogs(of medication: MedicationItem, from oldTimes: [Date], to newTimes: [Date]) {
        let calendar = Calendar.current

        /// A dose slot as minutes from midnight. An `(hour, minute)` tuple can't be
        /// used here: tuples can't conform to Equatable, so arrays of them have no
        /// `!=`. A single integer compares at any level.
        func slot(_ date: Date) -> Int {
            calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        }

        let oldSlots = oldTimes.map(slot)
        let newSlots = newTimes.map(slot)
        guard oldSlots != newSlots else { return }

        // Collected first and applied after: if one slot's new time equals another
        // slot's old time, mutating in place would swap the two.
        var moves: [(log: DoseLog, newDate: Date)] = []

        for (index, oldSlot) in oldSlots.enumerated() {
            guard index < newSlots.count else { break }
            let newSlot = newSlots[index]
            guard oldSlot != newSlot else { continue }

            for log in medication.logs where slot(log.scheduledTime) == oldSlot {
                if let moved = calendar.date(
                    bySettingHour: newSlot / 60,
                    minute: newSlot % 60,
                    second: 0,
                    of: log.scheduledTime
                ) {
                    moves.append((log, moved))
                }
            }
        }

        for move in moves {
            move.log.scheduledTime = move.newDate
        }
    }

    // MARK: - Toggle take

    func togglePill(medicationId: UUID, scheduledTime: Date) throws {
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
                med.stockCount = max(0, med.stockCount - med.dosage)
            } else {
                med.stockCount += med.dosage
            }
        } else {
            // actualTakeTime records when the dose was actually logged, which is how
            // lateness is captured: for a back-dated dose it exceeds scheduledTime.
            let newLog = DoseLog(scheduledTime: scheduledTime, isTaken: true)
            newLog.actualTakeTime = Date()
            med.logs.append(newLog)
            // Stock never goes negative. The clamp is asymmetric: logging doses at zero
            // stock and then un-logging them returns more than was deducted. Fixing that
            // means storing the deducted amount on DoseLog — a schema change.
            med.stockCount = max(0, med.stockCount - med.dosage)
        }
        try commit([.doses])
    }

    // MARK: - Course Management

    /// Looks a course up by id: NavigationPath stores the UUID, not the @Model
    /// object itself.
    func fetchCourse(id: UUID) -> TreatmentCourse? {
        let descriptor = FetchDescriptor<TreatmentCourse>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    func fetchAllCourses() -> [TreatmentCourse] {
        let descriptor = FetchDescriptor<TreatmentCourse>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func deleteCourse(_ course: TreatmentCourse) throws {
        // Deleting the course cascades to its MedicationItem records, but photo files
        // on disk are not removed automatically. Ids are captured before the delete and
        // the files erased after a successful commit, so a rollback can't leave a course
        // without its photos.
        let photoIds = course.medications.map(\.id)

        context.delete(course)
        try commit([.courses])

        for id in photoIds {
            ImageCache.shared.deleteFromDisk(for: id)
        }
    }

    func deleteMedication(_ medication: MedicationItem) throws {
        let photoId = medication.id
        context.delete(medication)
        try commit([.courses])

        // After the record is gone, so a rollback can't leave the medication in the
        // store without its photo.
        ImageCache.shared.deleteFromDisk(for: photoId)
    }

    func updateCourseDetails(course: TreatmentCourse, name: String, startDate: Date, endDate: Date) throws {
        course.name = name
        course.startDate = startDate
        course.endDate = endDate
        try commit([.courses])
    }

    func addMedication(draft: MedicationDraft, to course: TreatmentCourse) throws {
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

        try commit([.courses])

        if let imageData = draft.medicationImageData {
            ImageCache.shared.saveToDisk(imageData, for: med.id)
        }
    }

    // MARK: - Diary

    func saveDiaryEntry(draft: DiaryEntryDraft) throws {
        let entry = DiaryEntry(
            id: draft.id,
            checkInDate: draft.checkInDate,
            moodLabel: draft.mood.rawValue,
            moodScore: draft.mood.score,
            physicalSummary: draft.physicalSummary,
            energyLevel: draft.energyLevel,
            discomfortLevel: draft.discomfortLevel,
            sleepHours: draft.sleepHours,
            sleepQuality: draft.sleepQuality.rawValue,
            waterGlasses: draft.waterGlasses,
            symptoms: draft.symptoms,
            reflectionNotes: draft.reflectionNotes,
            milestoneTags: draft.milestoneTags,
            isQuickLog: draft.isQuickLog
        )

        // Ids are generated up front, files written only after commit — same approach
        // as MedicationItem's photo, see ImageCache.swift.
        let pendingPhotos = draft.photos.map { (UUID(), $0) }
        entry.photoIds = pendingPhotos.map(\.0)

        context.insert(entry)
        try commit([.diary])

        for (id, data) in pendingPhotos {
            ImageCache.shared.saveToDisk(data, for: id)
        }
    }

    func updateDiaryEntry(_ entry: DiaryEntry, with draft: DiaryEntryDraft) throws {
        entry.checkInDate = draft.checkInDate
        entry.moodLabel = draft.mood.rawValue
        entry.moodScore = draft.mood.score
        entry.physicalSummary = draft.physicalSummary
        entry.energyLevel = draft.energyLevel
        entry.discomfortLevel = draft.discomfortLevel
        entry.sleepHours = draft.sleepHours
        entry.sleepQuality = draft.sleepQuality.rawValue
        entry.waterGlasses = draft.waterGlasses
        entry.symptoms = draft.symptoms
        entry.reflectionNotes = draft.reflectionNotes
        entry.milestoneTags = draft.milestoneTags
        entry.isQuickLog = draft.isQuickLog

        // Replaced wholesale, but only when the user actually touched photos.
        // DiaryCheckInView.init(editingEntry:) always preloads existing photos into the
        // draft, so without this guard saving a mood change alone deleted every file and
        // rewrote byte-identical copies under fresh UUIDs.
        var removedPhotoIds: [UUID] = []
        var pendingPhotos: [(UUID, Data)] = []

        if draft.photosModified {
            removedPhotoIds = entry.photoIds
            pendingPhotos = draft.photos.map { (UUID(), $0) }
            entry.photoIds = pendingPhotos.map(\.0)
        }

        try commit([.diary])

        // Disk is synced only after the write succeeds.
        for id in removedPhotoIds {
            ImageCache.shared.deleteFromDisk(for: id)
        }
        for (id, data) in pendingPhotos {
            ImageCache.shared.saveToDisk(data, for: id)
        }
    }

    // MARK: - Blood pressure

    func saveBloodPressureReading(measuredAt: Date, systolic: Int, diastolic: Int, pulse: Int?) throws {
        let reading = BloodPressureReading(
            measuredAt: measuredAt,
            // Same clamping idiom as sleepHours above: a typo like 1200/80 would
            // otherwise flatten the whole chart.
            systolic: BloodPressureReading.systolicRange.clamping(systolic),
            diastolic: BloodPressureReading.diastolicRange.clamping(diastolic),
            pulse: pulse.map { BloodPressureReading.pulseRange.clamping($0) }
        )
        context.insert(reading)
        // Posted on the diary channel: the readings live on the diary's own
        // screen, and it is the only subscriber that needs to redraw.
        try commit([.diary])
    }

    func fetchAllBloodPressureReadings() -> [BloodPressureReading] {
        let descriptor = FetchDescriptor<BloodPressureReading>(
            sortBy: [SortDescriptor(\.measuredAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func deleteBloodPressureReading(_ reading: BloodPressureReading) throws {
        context.delete(reading)
        try commit([.diary])
    }

    /// Wipes the whole pressure history in one write.
    ///
    /// Deleted one by one rather than through a batch delete: a batch bypasses
    /// the context, so the rollback in `commit` would have nothing to undo if the
    /// save failed — and this is the one action here with no way back.
    func deleteAllBloodPressureReadings() throws {
        let readings = fetchAllBloodPressureReadings()
        guard !readings.isEmpty else { return }

        for reading in readings {
            context.delete(reading)
        }
        try commit([.diary])
    }

    func fetchAllDiaryEntries() -> [DiaryEntry] {
        let descriptor = FetchDescriptor<DiaryEntry>(sortBy: [SortDescriptor(\.checkInDate, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func deleteDiaryEntry(_ entry: DiaryEntry) throws {
        let photoIds = entry.photoIds

        context.delete(entry)
        try commit([.diary])

        // Clean up photo files on disk — they aren't removed automatically.
        for photoId in photoIds {
            ImageCache.shared.deleteFromDisk(for: photoId)
        }
    }
}

/// A storage write failure. A dedicated type so the UI can show readable text
/// instead of SwiftData's raw description.
enum DatabaseError: LocalizedError {
    case saveFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return String(localized: "Couldn't save your changes. They were not written to the device.")
        }
    }

    var failureReason: String? {
        switch self {
        case .saveFailed(let underlying):
            return underlying.localizedDescription
        }
    }
}

