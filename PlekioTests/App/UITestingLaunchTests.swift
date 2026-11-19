//
//  UITestingLaunchTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 18.11.2026.
//

#if DEBUG
import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("UI-testing launch mode")
struct UITestingLaunchTests {

    // MARK: - Arguments

    @Test("A normal launch is not a UI-testing launch")
    func normalLaunch() {
        #expect(UITestingLaunch(arguments: ["Plekio"]) == nil)
        // A seed alone, without the flag, must not switch the mode on.
        #expect(UITestingLaunch(arguments: ["Plekio", "-ui-seed", "today"]) == nil)
    }

    @Test("The flag alone starts empty")
    func flagAlone() {
        #expect(UITestingLaunch(arguments: ["Plekio", "-ui-testing"])?.seed == .empty)
    }

    @Test("The seed after -ui-seed is used", arguments: UITestingLaunch.Seed.allCases)
    func namedSeed(_ seed: UITestingLaunch.Seed) {
        let launch = UITestingLaunch(arguments: ["Plekio", "-ui-testing", "-ui-seed", seed.rawValue])
        #expect(launch?.seed == seed)
    }

    @Test("An unknown or missing seed name falls back to empty")
    func unknownSeed() {
        #expect(UITestingLaunch(arguments: ["Plekio", "-ui-testing", "-ui-seed", "nonsense"])?.seed == .empty)
        #expect(UITestingLaunch(arguments: ["Plekio", "-ui-testing", "-ui-seed"])?.seed == .empty)
    }

    @Test("The UI-testing location is not the App Group")
    func locationIsTemporary() {
        let root = UITestingLaunch.location.root.standardizedFileURL.path
        #expect(root.hasPrefix(FileManager.default.temporaryDirectory.standardizedFileURL.path))
    }

    @Test("-ui-now is read as local wall-clock time")
    func nowArgument() {
        let launch = UITestingLaunch(arguments: ["Plekio", "-ui-testing", "-ui-now", "2026-11-12T08:30"])
        #expect(launch?.now == testDate(2026, 11, 12, 8, 30))
    }

    @Test("A missing or malformed -ui-now keeps the real clock")
    func badNowArgument() {
        #expect(UITestingLaunch(arguments: ["Plekio", "-ui-testing"])?.now == nil)
        #expect(UITestingLaunch(arguments: ["Plekio", "-ui-testing", "-ui-now", "tomorrow"])?.now == nil)
        #expect(UITestingLaunch(arguments: ["Plekio", "-ui-testing", "-ui-now"])?.now == nil)
    }

    // MARK: - Clock

    @Test("The UI-testing clock starts at the given time and keeps running")
    func clockStartsThereAndRuns() {
        let start = testDate(2026, 11, 12, 8, 30)
        let realNow = Date()
        let clock = UITestingClock(startingAt: start, realNow: realNow)

        let elapsed = Date().timeIntervalSince(realNow)
        #expect(abs(clock.now.timeIntervalSince(start) - elapsed) < 1)
    }

    @Test("A launch with -ui-now gives the whole graph that clock")
    func graphUsesTheClock() {
        let start = testDate(2026, 11, 12, 8, 30)
        let dependencies = AppDependencies.uiTesting(UITestingLaunch(seed: .empty, now: start))

        #expect(abs(dependencies.time.now.timeIntervalSince(start)) < 5)
    }

    @Test("At a fixed time the today seed is the same every run")
    func todaySeedAtFixedTime() {
        let start = testDate(2026, 11, 12, 11, 0)
        let dependencies = AppDependencies.uiTesting(UITestingLaunch(seed: .today, now: start))
        let doses = dependencies.database.fetchPills(for: start, preFetchedCourses: nil)

        // 09:00 is two hours gone, past its grace hour; the other is due at 11:00.
        let morning = doses.first { $0.name == UITestingSeed.Names.morning }
        let dueNow = doses.first { $0.name == UITestingSeed.Names.dueNow }
        #expect(morning?.isMissed(at: start) == true)
        #expect(dueNow?.isMissed(at: start) == false)
    }

    // MARK: - Graph

    @Test("Every seed but onboarding skips onboarding and the tour")
    func onboardingFlags() {
        let empty = AppDependencies.uiTesting(UITestingLaunch(seed: .empty))
        #expect(empty.settings.hasSeenOnboarding)
        #expect(empty.settings.hasCompletedTour)

        let fresh = AppDependencies.uiTesting(UITestingLaunch(seed: .onboarding))
        #expect(!fresh.settings.hasSeenOnboarding)
        #expect(!fresh.settings.hasCompletedTour)
    }

    @Test("Each launch starts from a clean defaults domain")
    func defaultsAreWiped() {
        let first = AppDependencies.uiTesting(UITestingLaunch(seed: .empty))
        first.settings.isAppLockEnabled = true

        let second = AppDependencies.uiTesting(UITestingLaunch(seed: .empty))
        #expect(!second.settings.isAppLockEnabled)
    }

    @Test("The empty seed has no courses")
    func emptySeed() {
        let dependencies = AppDependencies.uiTesting(UITestingLaunch(seed: .empty))
        #expect(dependencies.database.fetchAllCourses().isEmpty)
    }

    @Test("The today seed has one course running today with two doses")
    func todaySeed() {
        let dependencies = AppDependencies.uiTesting(UITestingLaunch(seed: .today))

        let courses = dependencies.database.fetchAllCourses()
        #expect(courses.map(\.name) == [UITestingSeed.Names.course])
        #expect(Set(courses.first?.medications.map(\.name) ?? [])
            == [UITestingSeed.Names.morning, UITestingSeed.Names.dueNow])

        let doses = dependencies.database.fetchPills(for: dependencies.time.now, preFetchedCourses: nil)
        #expect(doses.count == 2)
    }

    @Test("The today seed always has an Up next card, whatever the time")
    func todaySeedHasUpNext() {
        let dependencies = AppDependencies.uiTesting(UITestingLaunch(seed: .today))
        let now = dependencies.time.now
        let doses = dependencies.database.fetchPills(for: now, preFetchedCourses: nil)

        let hero = DayHero(pills: doses, selectedDate: now, now: now, calendar: dependencies.time.calendar)
        #expect(hero.upNext?.isEmpty == false)
    }

    @Test("Reminders are never asked for or scheduled")
    func notificationsAreInert() async {
        let notifications = UITestingNotificationService()
        #expect(await notifications.delivery() == .on)
        #expect(await notifications.requestPermission())
    }
}
#endif
