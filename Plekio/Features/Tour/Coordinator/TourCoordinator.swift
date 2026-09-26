//
//  TourCoordinator.swift
//  Plekio
//
//  Created by Edward Gasparian on 26.09.2026.
//

import CoreGraphics
import Observation

/// Runs the first-run tour: which step is showing, which tab it needs, and where
/// its target is on screen. Shown once, after onboarding, only if there are no courses yet.
@Observable
@MainActor
final class TourCoordinator {

    // MARK: - Properties

    private(set) var step: TourStep?

    /// Global frames of the tagged views, as last laid out.
    private(set) var frames: [TourTarget: CGRect] = [:]

    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let router: AppRouter
    /// Called once the tour is over (or was over already); unlocks the contextual tips.
    @ObservationIgnored private let onFinish: () -> Void

    var isFinished: Bool { settings.hasCompletedTour }

    /// The step's target frame, if that view is on screen.
    var highlightedFrame: CGRect? {
        step?.target.flatMap { frames[$0] }
    }

    // MARK: - Init

    init(settings: SettingsStore, router: AppRouter, onFinish: @escaping () -> Void = {}) {
        self.settings = settings
        self.router = router
        self.onFinish = onFinish
    }

    // MARK: - Flow

    /// Someone who already has courses doesn't need the tour; it's marked done for them.
    func startIfNeeded(hasCourses: Bool) {
        guard step == nil else { return }
        guard !settings.hasCompletedTour else {
            onFinish()
            return
        }
        guard !hasCourses else {
            finish()
            return
        }
        show(.intro)
    }

    func next() {
        guard let step, !step.waitsForAction else { return }
        if let following = TourStep(rawValue: step.rawValue + 1) {
            show(following)
        } else {
            finish()
        }
    }

    /// The "create a course" step's action happened.
    func courseCreated() {
        guard step == .createCourse else { return }
        show(.logDose)
    }

    func skip() {
        guard step != nil else { return }
        finish()
    }

    // MARK: - Targets

    func update(_ target: TourTarget, frame: CGRect?) {
        frames[target] = frame
    }

    // MARK: - Private

    private func show(_ newStep: TourStep) {
        router.selectedTab = newStep.tab
        step = newStep
    }

    private func finish() {
        step = nil
        settings.hasCompletedTour = true
        onFinish()
    }
}
