import Foundation
import SwiftData

nonisolated extension SchemaV2 {

    /// The course dates in force before an edit. Past days keep their original
    /// bounds and frequency anchor; the current dates apply from the edit day.
    @Model
    nonisolated final class CourseDateRevision {
        /// Days as `LocalDay.stored`; read through `validUntilDay`, `startDay` and `endDay`.
        @Attribute(originalName: "validUntil") var storedValidUntil: Date = Date.distantPast
        @Attribute(originalName: "startDate") var storedStartDay: Date = Date.distantPast
        @Attribute(originalName: "endDate") var storedEndDay: Date = Date.distantPast
        var course: TreatmentCourse?

        init(validUntil: Date, startDate: Date, endDate: Date) {
            self.validUntil = validUntil
            self.startDate = startDate
            self.endDate = endDate
        }

        init(validUntilDay: LocalDay, startDay: LocalDay, endDay: LocalDay) {
            self.validUntilDay = validUntilDay
            self.startDay = startDay
            self.endDay = endDay
        }

        var validUntilDay: LocalDay {
            get { LocalDay(stored: storedValidUntil) }
            set { storedValidUntil = newValue.stored }
        }

        var startDay: LocalDay {
            get { LocalDay(stored: storedStartDay) }
            set { storedStartDay = newValue.stored }
        }

        var endDay: LocalDay {
            get { LocalDay(stored: storedEndDay) }
            set { storedEndDay = newValue.stored }
        }

        /// The days' midnights where the person is now; rules use the days.
        var validUntil: Date {
            get { validUntilDay.start(in: .autoupdatingCurrent) }
            set { validUntilDay = LocalDay(newValue, in: .autoupdatingCurrent) }
        }

        var startDate: Date {
            get { startDay.start(in: .autoupdatingCurrent) }
            set { startDay = LocalDay(newValue, in: .autoupdatingCurrent) }
        }

        var endDate: Date {
            get { endDay.start(in: .autoupdatingCurrent) }
            set { endDay = LocalDay(newValue, in: .autoupdatingCurrent) }
        }
    }
}
