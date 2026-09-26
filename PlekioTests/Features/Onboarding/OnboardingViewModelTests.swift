//
//  OnboardingViewModelTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("Onboarding")
struct OnboardingViewModelTests {

    // MARK: - Helpers

    /// A store over its own defaults suite, isolated from the app's settings.
    private func makeSettings() -> (SettingsStore, UserDefaults, String) {
        let suite = "PlekioTests.Onboarding.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (SettingsStore(defaults: defaults), defaults, suite)
    }

    // MARK: - Completing

    @Test("A fresh install hasn't seen onboarding")
    func freshInstallHasNotSeenOnboarding() {
        let (settings, defaults, suite) = makeSettings()
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(settings.hasSeenOnboarding == false)
    }

    @Test("Finishing onboarding writes the flag under the key ContentView reads")
    func completingWritesTheKeyContentViewReads() {
        let (settings, defaults, suite) = makeSettings()
        defer { defaults.removePersistentDomain(forName: suite) }
        let vm = OnboardingViewModel(settings: settings)

        vm.completeOnboarding()

        #expect(settings.hasSeenOnboarding)
        // ContentView reads this key via @AppStorage; any other key would reshow onboarding on every launch.
        #expect(defaults.bool(forKey: SettingsKey.hasSeenOnboarding))
    }

    @Test("The flag survives recreating the store, i.e. a relaunch")
    func flagSurvivesANewStore() {
        let (settings, defaults, suite) = makeSettings()
        defer { defaults.removePersistentDomain(forName: suite) }

        OnboardingViewModel(settings: settings).completeOnboarding()

        #expect(SettingsStore(defaults: defaults).hasSeenOnboarding)
    }

    @Test("Paging doesn't set the flag; only finishing explicitly does")
    func pagingAloneDoesNotComplete() {
        let (settings, defaults, suite) = makeSettings()
        defer { defaults.removePersistentDomain(forName: suite) }
        let vm = OnboardingViewModel(settings: settings)

        vm.currentPage = vm.pages.count - 1

        #expect(settings.hasSeenOnboarding == false)
    }

    // MARK: - Pages

    @Test("Only the last page counts as last")
    func isLastPageOnlyOnTheLast() {
        let (settings, defaults, suite) = makeSettings()
        defer { defaults.removePersistentDomain(forName: suite) }
        let vm = OnboardingViewModel(settings: settings)

        #expect(vm.currentPage == 0)
        #expect(vm.isLastPage == false)

        vm.currentPage = vm.pages.count - 2
        #expect(vm.isLastPage == false)

        vm.currentPage = vm.pages.count - 1
        #expect(vm.isLastPage)
    }

    @Test("Each part of the product is shown once, the report last")
    func pagesTellTheStoryOnce() {
        let previews = OnboardingViewModel.allPages.map(\.preview)

        #expect(Set(previews).count == previews.count)
        #expect(previews.last == .report)
    }

    @Test("Page ids are unique; the carousel's ForEach depends on them")
    func pageIdsAreUnique() {
        let ids = OnboardingViewModel.allPages.map(\.id)

        #expect(Set(ids).count == ids.count)
        // Ids must be stable across reads, or ForEach rebuilds every page on each render.
        #expect(OnboardingViewModel.allPages.map(\.id) == ids)
    }
}
