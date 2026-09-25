//
//  AppRouter.swift
//  Plekio
//
//  Created by Edward Gasparian on 14.06.2026.
//
//  Navigation state for the whole app, and the one entry point for deep links.
//
//  Owned by AppDependencies rather than created by the SwiftUI root, so it
//  exists from the first line of `didFinishLaunching`: a notification tapped on
//  a cold launch can be handed to it straight away. AppDelegate used to hold a
//  weak reference that SwiftUI filled in later, and buffer taps in two fields
//  of its own until it did.
//

import SwiftUI
import Combine

@MainActor
final class AppRouter: ObservableObject {

    @Published var selectedTab: AppTab = .today
    @Published var coursesPath = NavigationPath()

    @Published var activeSheet: SheetRoute?
    @Published var activeFullScreen: SheetRoute?

    /// A link waiting for the screen that presents it. Parked rather than acted
    /// on here, because on a cold launch it arrives before the tab bar is in the
    /// hierarchy — see MainTabView, which consumes it.
    @Published private(set) var pendingDeepLink: DeepLink?

    /// Which diary sub-tab to land on, set alongside a link that cares.
    /// Consumed by DiaryView on its own, since it is that screen's state.
    @Published private(set) var pendingDiarySubTab: DiarySubTab?

    // MARK: - Sheet presentation

    func present(_ sheet: SheetRoute) {
        activeSheet = sheet
    }

    func presentFullScreen(_ sheet: SheetRoute) {
        activeFullScreen = sheet
    }

    func dismissSheet() {
        activeSheet = nil
        activeFullScreen = nil
    }

    // MARK: - Deep links

    /// Switches to the link's tab and parks it for the screen that presents it.
    func open(_ link: DeepLink) {
        selectedTab = link.tab
        pendingDeepLink = link
        if let subTab = link.diarySubTab {
            pendingDiarySubTab = subTab
        }
    }

    /// Consumed rather than read: the link is presented from a `.task` and an
    /// `.onChange`, and both run for the same tap. A link that survived being
    /// read would be presented twice.
    func consumeDeepLink() -> DeepLink? {
        defer { pendingDeepLink = nil }
        return pendingDeepLink
    }

    func consumePendingDiarySubTab() -> DiarySubTab? {
        defer { pendingDiarySubTab = nil }
        return pendingDiarySubTab
    }
}
