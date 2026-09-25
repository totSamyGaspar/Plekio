//
//  ReportBuilder.swift
//  Plekio
//

import Foundation

/// Turns a selection into the values a report is drawn from.
///
/// The only place in the export that touches SwiftData. It asks `DoseSchedule`
/// what was due rather than deciding for itself: a report that counted doses by
/// its own rules would quietly disagree with the dashboard the user is looking
/// at.
@MainActor
struct ReportBuilder {

    private let database: any CourseStoring & DiaryStoring & BloodPressureStoring
    private let calendar: Calendar

    /// Injected so "missed" is testable without waiting for a dose to go stale.
    private let now: () -> Date

    init(
        database: any CourseStoring & DiaryStoring & BloodPressureStoring,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.database = database
        self.calendar = calendar
        self.now = now
    }

    /// `profile` is passed in rather than read here: the builder knows nothing
    /// about where settings live. Empty by default, which is what tests want.
    func build(_ selection: ReportSelection, profile: UserProfile = .empty) -> ReportData {
        let from = calendar.startOfDay(for: selection.from)
        let lastDay = calendar.startOfDay(for: selection.to)

        // One past the end, so a reading taken at 23:50 on the closing day is
        // inside the period rather than just outside it.
        let end = calendar.date(byAdding: .day, value: 1, to: lastDay) ?? lastDay

        return ReportData(
            profile: profile,
            from: from,
            to: lastDay,
            generatedAt: now(),
            courses: selection.includes(.medications)
                ? courses(selection.courseIds, from: from, throughDay: lastDay)
                : [],
            pressure: selection.includes(.bloodPressure)
                ? pressure(from: from, before: end)
                : [],
            diary: selection.includes(.diary)
                ? diary(from: from, before: end, withPhotos: selection.includesPhotos)
                : []
        )
    }

    // MARK: - Medications

    private func courses(_ ids: Set<UUID>, from: Date, throughDay lastDay: Date) -> [CourseReport] {
        database.fetchAllCourses()
            .filter { ids.contains($0.id) }
            .sorted { $0.startDate < $1.startDate }
            .map { course in
                CourseReport(
                    name: course.name,
                    startDate: course.startDate,
                    endDate: course.endDate,
                    medications: course.medications
                        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                        .map { report(for: $0, in: course, from: from, throughDay: lastDay) }
                )
            }
    }

    private func report(
        for medication: MedicationItem,
        in course: TreatmentCourse,
        from: Date,
        throughDay lastDay: Date
    ) -> MedicationReport {
        let courseStart = calendar.startOfDay(for: course.startDate)
        let courseEnd = calendar.startOfDay(for: course.endDate)
        let logs = logsBySlot(of: medication)

        var adherence = Adherence.none
        var exceptions: [DoseException] = []

        // The period and the course overlap; outside the overlap the schedule
        // called for nothing, so there is nothing to count either way.
        for day in days(from: max(from, courseStart), through: min(lastDay, courseEnd)) {
            let slots = DoseSchedule.slots(
                for: medication,
                courseStartDay: courseStart,
                courseEndDay: courseEnd,
                on: day,
                calendar: calendar
            )

            for slot in slots {
                switch outcome(at: slot.date, logs: logs) {
                case .taken:
                    adherence.taken += 1
                case .skipped:
                    adherence.skipped += 1
                    exceptions.append(DoseException(time: slot.date, kind: .skipped))
                case .missed:
                    adherence.missed += 1
                    exceptions.append(DoseException(time: slot.date, kind: .missed))
                case .upcoming:
                    adherence.upcoming += 1
                }
            }
        }

        return MedicationReport(
            name: medication.name,
            dosage: medication.dosage,
            timesOfDay: medication.timesOfDay,
            frequencyDays: medication.frequencyDays,
            adherence: adherence,
            exceptions: exceptions.sorted { $0.time < $1.time }
        )
    }

    private enum Outcome {
        case taken, skipped, missed, upcoming
    }

    private func outcome(at slot: Date, logs: [DateComponents: DoseLog]) -> Outcome {
        let log = logs[DoseSchedule.slotKey(slot, calendar: calendar)]

        switch log?.status {
        case .taken: return .taken
        case .skipped: return .skipped
        case .pending, nil: break
        }

        return slot.addingTimeInterval(DoseSchedule.missedGrace) < now() ? .missed : .upcoming
    }

    /// Every log of a medication, indexed once. Scanning the array per slot
    /// turns a year-long course into hundreds of thousands of comparisons.
    private func logsBySlot(of medication: MedicationItem) -> [DateComponents: DoseLog] {
        Dictionary(
            medication.logs.map { (DoseSchedule.slotKey($0.scheduledTime, calendar: calendar), $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    // MARK: - Diary and blood pressure

    private func pressure(from: Date, before end: Date) -> [PressureReading] {
        database.fetchAllBloodPressureReadings()
            .filter { $0.measuredAt >= from && $0.measuredAt < end }
            .sorted { $0.measuredAt < $1.measuredAt }
            .map {
                PressureReading(
                    measuredAt: $0.measuredAt,
                    systolic: $0.systolic,
                    diastolic: $0.diastolic,
                    pulse: $0.pulse
                )
            }
    }

    private func diary(from: Date, before end: Date, withPhotos: Bool) -> [DiaryDay] {
        database.fetchAllDiaryEntries()
            .filter { $0.checkInDate >= from && $0.checkInDate < end }
            .sorted { $0.checkInDate < $1.checkInDate }
            .map { entry in
                DiaryDay(
                    date: entry.checkInDate,
                    mood: entry.moodTitle,
                    moodScore: entry.moodScore,
                    energyLevel: entry.energyLevel,
                    discomfortLevel: entry.discomfortLevel,
                    sleepHours: entry.sleepHours,
                    sleepQuality: entry.sleepQuality,
                    waterGlasses: entry.waterGlasses,
                    symptoms: entry.symptoms,
                    notes: entry.displayCaption,
                    photoIds: withPhotos ? entry.photoIds : [],
                    isQuickLog: entry.isQuickLog
                )
            }
    }

    // MARK: - Days

    private func days(from: Date, through last: Date) -> [Date] {
        guard from <= last else { return [] }

        var result: [Date] = []
        var day = from

        while day <= last {
            result.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }
}
