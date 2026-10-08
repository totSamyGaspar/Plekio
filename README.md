# Plekio

A medication tracker for iOS. Plan treatment courses, get reminded when a dose is due, log it in one tap, and keep a well-being diary you can hand to your doctor as a PDF.

Everything stays on the device: no account, no server, no analytics.

## Features

- **Today** — the day's doses by morning, afternoon and evening, with an "Up next" card that logs a whole slot at once. Once every dose is logged, the card turns over to a summary of the day and the current streak. Any log can be undone.
- **Courses** — medications with dosage, times of day, every-N-days schedules, start and end dates, stock and a low-stock threshold. Finished courses move to History and can be repeated with new dates. Schedule changes apply from the day they're made, so past days keep the plan that was in force.
- **Reminders** — a local notification per dose slot with Take / Snooze / Skip, working from the lock screen. The app icon badge shows the doses that are due and not logged yet. There are optional daily diary and blood-pressure reminders, and a daily reminder while any medication is running low.
- **Diary** — mood, energy, discomfort, sleep, water, symptoms, milestones and photos. Includes mood trends, a progress-photo gallery with side-by-side comparison, and blood-pressure readings with a chart.
- **Doctor report** — a PDF of doses, well-being and blood pressure for any period.
- **Onboarding and first-run tour**, plus one-time TipKit hints where features live.
- **Accessibility** — Dynamic Type, VoiceOver labels, and Reduce Motion across all animations.
- **Localized** in English, German, Spanish, French, Italian, Japanese, Kazakh, Romanian, Russian and Ukrainian.

## Requirements

- Xcode 26 or later (the app icon uses the Icon Composer `.icon` format)
- iOS 18.0 or later
- No third-party dependencies

## Getting started

```sh
git clone https://github.com/totSamyGaspar/Plekio.git
open Plekio/Plekio.xcodeproj
```

Select the **Plekio** scheme and run it on a simulator or a device. To run on a device, set your own team under *Signing & Capabilities*.

The data schema is frozen at `SchemaV1` (git tag `schema-v1`): a build must open every store an earlier release wrote. See *Schema changes* below.

## Tests

Run all tests with **⌘U**. The suite uses Swift Testing.

The **Plekio** scheme pins the test environment so date and locale assertions don't depend on the machine:

- `TZ=Europe/Berlin`
- `-AppleLocale uk_UA`

Test names are in English; assertions and code are in English.

- **Schema freeze.** `SchemaFreezeTests` compares `SchemaV1` with `PlekioTests/Fixtures/SchemaV1.manifest` and opens `SchemaV1.store`, a store V1 wrote, with the current schema. Never regenerate those files.
- **StoreKit.** Tip tests run against `PlekioTests/Support/Plekio.storekit`. Purchase tests run only while `AppFeatures.tips` is on, and only on iOS 27.

## CI

Xcode Cloud, workflow **Tests**: every pull request into `main` and every push to `main` builds and runs the tests on one iPhone simulator with the latest iOS. A PR is merged only when it is green.

## Releasing

Follow [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md). The support page, privacy policy and terms of use live in `docs/` and are published with GitHub Pages at https://totsamygaspar.github.io/Plekio/.

## Architecture

Course date edits apply from the start of the edit day. Earlier days retain their
original course bounds and every-N-days anchor, including days with no doses.
Changing dates repeatedly in one day preserves the state before the first edit.
Snoozes are checked against the original dose's schedule, even if its course has
since finished; removing that slot cancels its snooze on the next rebuild.

SwiftUI views over MVVM, with a small domain layer and a single composition root.

```
View  →  ViewModel  →  Use case  →  Repository / Store  →  SwiftData
                          ↓
                    Services (notifications, PDF)
```

- **Composition root.** `AppDependencies` builds the object graph once and hands out view models (`make…ViewModel()`). It is owned by `AppDelegate`, so a notification action on a cold launch uses the same graph as the UI.
- **View models.** Each screen has a protocol (`…ViewModelProtocol`), a live implementation and a mock for previews. Main-actor isolated by default (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`).
- **Use cases** hold the rules that span several stores. Examples:
  - `DoseLoggingUseCase` logs, skips and reverts doses and rebuilds reminders;
  - `DoseUndoCenter` owns the undo window;
  - `CourseEditingUseCase` handles course edits;
  - `BloodPressureLogging` validates readings before saving them.
- **Domain.** SwiftData models (`@Model`), pure rules (`DoseSchedule`, `DoseDay`, `DoseStatus`, `StockRules`) and value snapshots for the UI. Rules are `nonisolated`, so they can run off the main actor.
- **Data.**
  - `DatabaseService` is the SwiftData store; writes commit through one point and roll back on failure.
  - `DatabaseChangeFeed` announces what a write touched (courses, doses, diary), so screens reload only what they show.
  - Heavy reads (history, statistics, the PDF) run on a `@ModelActor` (`BackgroundReader`).
- **Notifications.**
  - `ReminderPlanner` decides what to schedule, within iOS's 64-request limit.
  - `ReminderRequestFactory` builds the requests.
  - `NotificationService` serializes rebuilds.
  - `ReminderSyncCoordinator` rebuilds when courses change or the app becomes active.
- **Time.** Everything that needs "now" or a calendar gets a `TimeSource`, so tests can pin the clock.
- **Motion.** `Motion` defines the app's animation curves; `motion(_:value:)` and `withMotion` drop movement under Reduce Motion.

## Project structure

```
Plekio/
├── App/            Entry point, AppDelegate, splash
├── Core/           DI, navigation (AppRouter, deep links), errors, settings, time, toasts, logging
├── Domain/         SwiftData models, rules, snapshots, versioned schema
├── Data/           SwiftData store, repositories, photo storage and cache
├── UseCases/       Dose logging and undo, course editing, diary, reminders
├── Services/       Notifications, PDF report
├── Features/       One folder per screen: Model / View / ViewModel
│   ├── Dashboard   Today
│   ├── Courses     Active courses, history, course detail
│   ├── NewTreatment
│   ├── Diary       Journal, check-in, photos, blood pressure
│   ├── Statistics, Export, Settings, Onboarding, Tour, MainTab
├── UI/             Shared components, layout, theme and motion
└── Resources/      Assets, app icon, Localizable.xcstrings
PlekioTests/        Mirrors the app's folders; Mocks/ and Support/ hold test doubles
```

## Conventions
- **Comments** explain *why*, not *what*.
- **Localization:** every user-facing string lives in `Localizable.xcstrings` and is translated into all supported languages.
- **Schema changes:** `SchemaV1` is frozen. A model change goes into a new `SchemaV2` with a migration stage, following the steps at the top of `PlekioSchema.swift`; extend `SchemaV1Fixture.expectMatches` for it.
- **Previews and mocks** live inside `#if DEBUG`, so they never reach the App Store build.
- **Feature flags** are in `AppFeatures` and read only in the composition root.
- **Branches and PRs:** one branch per change, merged into `main` by pull request once Xcode Cloud is green; merged branches are deleted.
- **Commits:** short imperative subject, e.g. `Diary: entries can't be dated in the future`, then a body that says what changed and why.
