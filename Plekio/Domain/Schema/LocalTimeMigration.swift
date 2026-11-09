//
//  LocalTimeMigration.swift
//  Plekio
//
//  Created by Edward Gasparian on 09.11.2026.
//

import Foundation
import SwiftData

/// The data half of the V1 → V2 migration. V1 stored course days, revisions and
/// dose slots as moments; V2 stores them as local days and times (`LocalDay`,
/// `LocalSlot`). Each moment is reread as the day and time it was in `calendar`'s
/// time zone: the device's at the update, where nearly every record was made.
/// Names V2's models explicitly: this belongs to V2 whatever `Current` becomes.
nonisolated enum LocalTimeMigration {

    static func run(in context: ModelContext, calendar: Calendar) throws {
        func day(_ moment: Date) -> Date { LocalDay(moment, in: calendar).stored }

        for course in try context.fetch(FetchDescriptor<SchemaV2.TreatmentCourse>()) {
            course.storedStartDay = day(course.storedStartDay)
            course.storedEndDay = day(course.storedEndDay)
        }
        for revision in try context.fetch(FetchDescriptor<SchemaV2.CourseDateRevision>()) {
            revision.storedValidUntil = day(revision.storedValidUntil)
            revision.storedStartDay = day(revision.storedStartDay)
            revision.storedEndDay = day(revision.storedEndDay)
        }
        for revision in try context.fetch(FetchDescriptor<SchemaV2.ScheduleRevision>()) {
            revision.storedValidUntil = day(revision.storedValidUntil)
        }
        for medication in try context.fetch(FetchDescriptor<SchemaV2.MedicationItem>()) {
            medication.storedStartDay = medication.storedStartDay.map(day)
        }
        for log in try context.fetch(FetchDescriptor<SchemaV2.DoseLog>()) {
            log.storedSlot = LocalSlot(log.storedSlot, in: calendar).stored
        }
        try context.save()
    }
}
