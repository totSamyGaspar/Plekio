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
