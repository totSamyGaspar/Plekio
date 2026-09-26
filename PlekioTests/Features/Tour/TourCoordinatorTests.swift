//
//  TourCoordinatorTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 26.09.2026.
//

import Testing
import Foundation
@testable import Plekio
internal import CoreGraphics

@MainActor
@Suite("TourCoordinator")
struct TourCoordinatorTests {

    // MARK: - Helpers

    @MainActor
    private final class Harness {
        let defaults: UserDefaults
        let suite = "PlekioTests.Tour.\(UUID().uuidString)"
        let settings: SettingsStore
        let router = AppRouter()
        var finishCount = 0
        lazy var tour = TourCoordinator(settings: settings, router: router) { [unowned self] in finishCount += 1 }

        init() {
            defaults = UserDefaults(suiteName: suite)!
            settings = SettingsStore(defaults: defaults)
        }

        deinit { UserDefaults().removePersistentDomain(forName: suite) }
    }

    // MARK: - Starting

    @Test("Without courses the tour starts on Today")
    func startsOnTodayWithoutCourses() {
        let h = Harness()
        h.router.selectedTab = .settings

        h.tour.startIfNeeded(hasCourses: false)

        #expect(h.tour.step == .intro)
        #expect(h.router.selectedTab == .today)
    }

    @Test("With existing courses the tour isn't shown and is marked done")
    func skippedWhenCoursesExist() {
        let h = Harness()

        h.tour.startIfNeeded(hasCourses: true)

        #expect(h.tour.step == nil)
        #expect(h.settings.hasCompletedTour)
        #expect(h.finishCount == 1)
    }

    @Test("A finished tour isn't shown again, but tips unlock")
    func finishedTourNeverRestarts() {
        let h = Harness()
        h.settings.hasCompletedTour = true

        h.tour.startIfNeeded(hasCourses: false)

        #expect(h.tour.step == nil)
        #expect(h.finishCount == 1)
    }

    // MARK: - Flow

    @Test("Next goes to Courses and the + button, and the step waits for a course")
    func nextLeadsToCoursesAndWaits() {
        let h = Harness()
        h.tour.startIfNeeded(hasCourses: false)

        h.tour.next()
        #expect(h.tour.step == .createCourse)
        #expect(h.router.selectedTab == .courses)

        // "Next" can't skip the action step.
        h.tour.next()
        #expect(h.tour.step == .createCourse)
    }

    @Test("A created course returns to Today, and the last step ends the tour")
    func courseCreatedThenFinish() {
        let h = Harness()
        h.tour.startIfNeeded(hasCourses: false)
        h.tour.next()

        h.tour.courseCreated()
        #expect(h.tour.step == .logDose)
        #expect(h.router.selectedTab == .today)

        h.tour.next()
        #expect(h.tour.step == nil)
        #expect(h.settings.hasCompletedTour)
        #expect(h.finishCount == 1)
    }

    @Test("Creating a course outside the tour changes nothing")
    func courseCreatedOutsideTheTourIsIgnored() {
        let h = Harness()
        h.tour.courseCreated()
        #expect(h.tour.step == nil)
        #expect(!h.settings.hasCompletedTour)
    }

    @Test("Skip ends the tour from any step")
    func skipFinishes() {
        let h = Harness()
        h.tour.startIfNeeded(hasCourses: false)
        h.tour.next()

        h.tour.skip()

        #expect(h.tour.step == nil)
        #expect(h.settings.hasCompletedTour)
    }

    @Test("The highlight is the current step's target frame")
    func highlightedFrameFollowsTheStep() {
        let h = Harness()
        let frame = CGRect(x: 300, y: 60, width: 44, height: 44)
        h.tour.update(.newCourseButton, frame: frame)
        h.tour.startIfNeeded(hasCourses: false)

        #expect(h.tour.highlightedFrame == nil)
        h.tour.next()
        #expect(h.tour.highlightedFrame == frame)
    }
}
