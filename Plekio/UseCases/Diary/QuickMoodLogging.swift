//
//  QuickMoodLogging.swift
//  Plekio
//
//  Created by Edward Gasparian on 22.10.2026.
//

import Foundation

// MARK: - QuickMoodLogging

/// A mood logged in one tap, from the diary's Today card or the widget. One rule
/// for both, so a tap on the widget can't add a second entry the card wouldn't.
@MainActor
final class QuickMoodLogging {

    private let diary: any DiaryRepository
    private let errors: any ErrorReporting
    private let time: any TimeSource

    init(diary: any DiaryRepository, errors: any ErrorReporting, time: any TimeSource) {
        self.diary = diary
        self.errors = errors
        self.time = time
    }

    /// One entry per day: today's mood changes if there is an entry, else a quick
    /// log is added. Whether it was saved; a failure has already been reported.
    @discardableResult
    func log(_ mood: DiaryMood) -> Bool {
        let now = time.now
        let today = diary.allEntries().first { time.calendar.isDate($0.checkInDate, inSameDayAs: now) }

        if let today {
            var draft = DiaryEntryDraft(from: today)
            draft.mood = mood
            return errors.run { try diary.updateEntry(id: today.id, with: draft) }
        }

        var draft = DiaryEntryDraft()
        draft.mood = mood
        // Energy/sleep/water are defaults, not user input; stats must exclude them.
        draft.isQuickLog = true
        return errors.run { try diary.saveEntry(draft) }
    }
}
