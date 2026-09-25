//
//  TimeSource.swift
//  Plekio
//
//  Where "now" comes from.
//
//  Almost every rule in this app is a rule about time: a dose is missed an hour
//  after its slot, a course is active until the end of its last day, the streak
//  counts back from today, the reminder queue covers a window ahead of now.
//  Reading `Date()` inside those rules made them untestable at the edges that
//  matter — midnight, the grace period, a course ending today — without waiting
//  for the real clock to get there.
//
//  Logic takes a TimeSource; the app passes SystemTime, a test passes a fixed
//  one. Named TimeSource rather than Clock, which the standard library already
//  uses for something else.
//
//  Left on `Date()` on purpose: view-level defaults that mean "the moment this
//  renders" — a date picker's starting value, the undo banner's countdown.
//
//  The calendar comes from the same place. "Now" alone does not decide which
//  day a dose falls on: midnight, the start of the week and a DST switch are
//  the calendar's. Read as `Calendar.current` inside the rules, they followed
//  whatever time zone and region the machine running the tests happened to
//  have.
//

import Foundation

nonisolated protocol TimeSource: Sendable {
    var now: Date { get }
    /// The calendar "today", "this week" and "midnight" are counted in.
    var calendar: Calendar { get }
}

/// The real clock, in the user's calendar and time zone.
nonisolated struct SystemTime: TimeSource {
    init() {}
    var now: Date { Date() }
    /// Autoupdating, so a time zone change while the app runs is picked up.
    var calendar: Calendar { .autoupdatingCurrent }
}
