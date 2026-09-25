//
//  AppRouter.swift
//  Plekio
//
//  Created by Edward Gasparian on 14.06.2026.
//

import SwiftUI
import Combine

@MainActor
final class AppRouter: ObservableObject {

    // MARK: - Properties

    @Published var selectedTab: AppTab = .today
    @Published var coursesPath = NavigationPath()

    @Published var activeSheet: SheetRoute?
    @Published var activeFullScreen: SheetRoute?

    /// Parked for MainTabView: on a cold launch it arrives before the tab bar exists.
    @Published private(set) var pendingDeepLink: DeepLink?

    /// Diary sub-tab to land on; consumed by DiaryView.
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

    /// Consumed, not read: both a `.task` and an `.onChange` handle the same tap,
    /// so a link that survived a read would be presented twice.
    func consumeDeepLink() -> DeepLink? {
        defer { pendingDeepLink = nil }
        return pendingDeepLink
    }

    func consumePendingDiarySubTab() -> DiarySubTab? {
        defer { pendingDiarySubTab = nil }
        return pendingDiarySubTab
    }
}
