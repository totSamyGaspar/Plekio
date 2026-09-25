//
//  OnboardingViewModelTests.swift
//  PlekioTests
//
//  Onboarding runs once per install, so a regression here is one nobody on the
//  team sees again after their first launch. The flag it writes is read by
//  ContentView through `@AppStorage`, a second path to the same key, and these
//  tests pin both ends of that path to one place.
//

import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("Onboarding")
struct OnboardingViewModelTests {

    /// A store over a suite of its own, so nothing touches the app's settings.
    private func makeSettings() -> (SettingsStore, UserDefaults, String) {
        let suite = "PlekioTests.Onboarding.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (SettingsStore(defaults: defaults), defaults, suite)
    }

    // MARK: - Completing

    @Test("новая установка онбординг ещё не видела")
    func freshInstallHasNotSeenOnboarding() {
        let (settings, defaults, suite) = makeSettings()
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(settings.hasSeenOnboarding == false)
    }

    @Test("завершение онбординга записывает флаг под тем ключом, что читает ContentView")
    func completingWritesTheKeyContentViewReads() {
        let (settings, defaults, suite) = makeSettings()
        defer { defaults.removePersistentDomain(forName: suite) }
        let vm = OnboardingViewModel(settings: settings)

        vm.completeOnboarding()

        #expect(settings.hasSeenOnboarding)
        // ContentView reads `@AppStorage(SettingsKey.hasSeenOnboarding)` from
        // the same defaults (`.defaultAppStorage` at the root). If the store
        // wrote under any other key, onboarding would show on every launch.
        #expect(defaults.bool(forKey: SettingsKey.hasSeenOnboarding))
    }

    @Test("флаг переживает пересоздание хранилища — то есть перезапуск")
    func flagSurvivesANewStore() {
        let (settings, defaults, suite) = makeSettings()
        defer { defaults.removePersistentDomain(forName: suite) }

        OnboardingViewModel(settings: settings).completeOnboarding()

        #expect(SettingsStore(defaults: defaults).hasSeenOnboarding)
    }

    @Test("пролистывание страниц флаг не ставит — только явное завершение")
    func pagingAloneDoesNotComplete() {
        let (settings, defaults, suite) = makeSettings()
        defer { defaults.removePersistentDomain(forName: suite) }
        let vm = OnboardingViewModel(settings: settings)

        vm.currentPage = vm.pages.count - 1

        #expect(settings.hasSeenOnboarding == false)
    }

    // MARK: - Pages

    @Test("последней считается только последняя страница")
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

    @Test("каждая часть продукта показана один раз, отчёт — в конце")
    func pagesTellTheStoryOnce() {
        let previews = OnboardingViewModel.allPages.map(\.preview)

        #expect(Set(previews).count == previews.count)
        // The report is the payoff — see the comment on OnboardingViewModel.
        #expect(previews.last == .report)
    }

    @Test("id страниц уникальны — на них держится ForEach карусели")
    func pageIdsAreUnique() {
        let ids = OnboardingViewModel.allPages.map(\.id)

        #expect(Set(ids).count == ids.count)
        // `allPages` is a stored static, so the ids are made once. Were it
        // computed, each read would mint new UUIDs and ForEach would rebuild
        // every page on every render.
        #expect(OnboardingViewModel.allPages.map(\.id) == ids)
    }
}
