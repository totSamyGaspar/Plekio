//
//  MainTabView.swift
//  Plekio
//
//  Created by Edward Gasparian on 03.05.2026.
//

import SwiftUI

struct MainTabView: View {
    @Environment(AppDependencies.self) private var dependencies
    @EnvironmentObject var router: AppRouter
    
    /// The one write-failure alert for the whole app, instead of the same
    /// `.alert` repeated across seven screens.
    /// Read through the environment and observed by `@Observable`: reading
    /// `message` in the body is enough for the alert to follow it.
    private var errorPresenter: AppErrorPresenter { dependencies.errorPresenter }
    
    static func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        
        if UIAccessibility.isReduceTransparencyEnabled {
            // Reduce Transparency asks for a solid bar, not a thinner blur.
            // Read once here: an appearance applies to bars as they are created,
            // so a mid-session change to the setting lands on the next launch.
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = .appSurfaceOpaque
        } else {
            appearance.configureWithDefaultBackground()
            // The plain material, not the ...Dark variant: it resolves per trait
            // collection, so the bar follows the theme without being rebuilt.
            appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
            appearance.backgroundColor = .appTabBarWash
        }
        
        appearance.stackedLayoutAppearance.selected.iconColor = .appAccent
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.appAccent]
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.systemGray
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.systemGray]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        TabView(selection: $router.selectedTab) {
            NavigationStack {
                DashboardView(viewModel: dependencies.makeDashboardViewModel())
            }
            .tabItem { Label("Today", systemImage: "calendar.day.timeline.left") }
            .tag(0)
            
            NavigationStack(path: $router.coursesPath) {
                CoursesListView(viewModel: dependencies.makeCoursesListViewModel())
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case .courseDetail(let courseId):
                            CourseDetailDestination(courseId: courseId)
                        }
                    }
            }
            .tabItem { Label("Courses", systemImage: "list.clipboard.fill") }
            .tag(1)
            
            NavigationStack {
                DiaryView(viewModel: dependencies.makeDiaryViewModel())
            }
            .tabItem { Label("Diary", systemImage: "text.book.closed.fill") }
            .tag(2)
            
            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            .tag(3)
        }
        .tint(.accentPrimary)
        .appTheme()
        .sheet(item: $router.activeSheet) { sheet in
            sheetContent(for: sheet)
        }
        .fullScreenCover(item: $router.activeFullScreen) { sheet in
            sheetContent(for: sheet)
        }
        .onChange(of: router.selectedTab) { _, _ in
            UISelectionFeedbackGenerator().selectionChanged()
        }
        // Handled here rather than in DashboardView: this screen presents the modal
        // and stays alive as long as the app is open.
        //
        // Both entry points are needed. On a cold start the payload is set before this
        // view reaches the hierarchy, and onChange only sees changes made while the
        // view is alive — so .task takes the value already waiting, onChange the ones
        // arriving later. The pause is not cosmetic: on a cold start this screen
        // appears inside the transition from ContentView, and SwiftUI drops a
        // fullScreenCover requested while the presenting view is still appearing.
        .task {
            try? await Task.sleep(for: .seconds(RootTransition.presentationDelay))
            consumePendingPush()
            consumePendingReminder()
        }
        .onChange(of: router.pendingPushMedicationIds) { _, _ in consumePendingPush() }
        .onChange(of: router.pendingReminder) { _, _ in consumePendingReminder() }
        .alert(
            "Couldn't save",
            isPresented: Binding(
                get: { errorPresenter.message != nil },
                set: { if !$0 { errorPresenter.message = nil } }
            ),
            presenting: errorPresenter.message
        ) { _ in
            Button("OK", role: .cancel) { errorPresenter.message = nil }
        } message: { text in
            Text(text)
        }
    }
    
    // MARK: - Push
    
    private func consumePendingPush() {
        guard let (medicationIds, scheduledTime) = router.consumePendingPush() else { return }

        let doseLogging = dependencies.doseLogging

        // Doses come from the schedule by slot time, not from the dashboard view
        // model, so the modal does not depend on whether that screen is rendered or
        // on which date it happens to be showing.
        let pills = doseLogging.openDoses(medicationIds: medicationIds, at: scheduledTime)
        guard !pills.isEmpty else { return }

        // No Task here: the write is synchronous, and the reminder rebuild runs
        // behind it on its own — nothing on screen waits for it.
        router.presentFullScreen(
            .takePill(
                pills: pills,
                onTake: {
                    _ = errorPresenter.attempt { try doseLogging.markTaken(pills) }
                },
                onSkip: {
                    _ = errorPresenter.attempt { try doseLogging.markSkipped(pills) }
                }
            )
        )
    }

    /// Presented from here rather than from the diary screen: on a cold launch a
    /// reminder is tapped before that screen is in the hierarchy, which is the
    /// same reason the dose push is handled here.
    private func consumePendingReminder() {
        guard let reminder = router.consumePendingReminder() else { return }
        
        switch reminder {
        case .diary:
            router.present(.diaryCheckIn)
        case .bloodPressure:
            router.present(.bloodPressureEntry)
        }
    }
    
    @ViewBuilder
    private func sheetContent(for sheet: SheetRoute) -> some View {
        switch sheet {
            
        case .newTreatment:
            NewTreatmentView(viewModel: dependencies.makeNewTreatmentViewModel())
                .appTheme()
            
        case .diaryCheckIn:
            DiaryCheckInView(viewModel: dependencies.makeDiaryCheckInViewModel())
                .appTheme()
            
        case .bloodPressureEntry:
            BloodPressureEntryView { measuredAt, systolic, diastolic, pulse in
                PendingBloodPressureReading.save(
                    measuredAt: measuredAt, systolic: systolic, diastolic: diastolic, pulse: pulse,
                    diary: dependencies.diaryRepository,
                    errors: errorPresenter
                )
            }
            .appTheme()
            
        case .takePill(let pills, let onTake, let onSkip):
            TakePillModalView(pills: pills, onTake: {
                onTake()
                router.dismissSheet()
            }, onSkip: {
                onSkip()
                router.dismissSheet()
            }, onSnooze: {
                let notifService = dependencies.notifications
                let ids = pills.map { $0.medicationId.uuidString }
                let names = pills.map { $0.name }
                Task { await notifService.scheduleSnooze(for: ids, names: names) }
                router.dismissSheet()
            })
            .presentationBackground(.clear)
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppRouter())
        .environment(AppDependencies.preview)
}
