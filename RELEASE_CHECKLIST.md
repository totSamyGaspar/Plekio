# Release checklist

Go through this for every build that leaves your Mac: a TestFlight build, an App Store release, a hotfix. Items marked **(first release)** are one-time.

## 1. Code is ready

- [ ] `main` is green on Xcode Cloud (workflow **Tests**).
- [ ] **⌘U locally on an iOS 27 simulator.** Xcode Cloud skips what it can't run there, so local is the only full run.
- [ ] **Archive in Release** (*Any iOS Device* → *Product → Archive*) before you rely on it. Debug builds and tests don't compile Release, so a `#Preview` or other code outside `#if DEBUG` that uses a preview-only mock fails only here.
- [ ] No leftover debug code: `print`, test data, temporary flags.
- [ ] `AppFeatures` reviewed. Every flag is set to what this release should ship (see *Feature flags* below).

## 2. Data and schema

The store holds people's medication history. A broken migration loses it.

- [ ] **No model changed?** Then `SchemaFreezeTests` is green and there's nothing else to do.
- [ ] **A model changed?**
  - Add `SchemaV(n+1)` as described at the top of `PlekioSchema.swift`.
  - Add the migration stage.
  - Extend `SchemaV1Fixture.expectMatches`.
- [ ] **Never regenerate an existing fixture.** `Fixtures/SchemaV1.*` are written once, by the code that shipped V1.
- [ ] **The first release that ships V(n+1):**
  - Freeze it the same way (`SchemaV(n+1).manifest` and `.store`, written by its own generator test).
  - Tag `schema-v(n+1)`.
- [ ] **Update test on a device:**
  1. Install the previous TestFlight build and add some data.
  2. Install the new build over it.
  3. Check that everything is still there.

## 3. Strings, privacy, legal

- [ ] **Translations.** Every new string is translated into all ten languages. No `needs_review` entries are left in `Localizable.xcstrings`: search the file for `needs_review`.
- [ ] **`PrivacyInfo.xcprivacy`.** Still true:
  - no tracking;
  - no collected data;
  - every required-reason API is declared.

  Recheck it after adding any SDK or any new use of UserDefaults, file timestamps, disk space or boot time.
- [ ] **`docs/` matches the app.** Update the date in each changed page:
  - `privacy-policy.md`: what is stored, permissions, sharing;
  - `terms.md`;
  - `index.md`: support answers.
- [ ] **GitHub Pages has deployed.** Repository → *Actions* → *pages build and deployment*.
- [ ] **App Store Connect → App Privacy** still matches. Today the answer is "Data Not Collected".

## 4. Version

- [ ] **Version** (`MARKETING_VERSION`, target → General):
  - bump it for a new App Store release (1.0 → 1.1);
  - keep it for more TestFlight builds of the same release.
- [ ] **Build** (`CURRENT_PROJECT_VERSION`) is higher than any build already uploaded, for manual uploads. App Store Connect rejects a repeated number. Xcode Cloud archives number themselves.

## 5. Smoke test on a real iPhone

Release build from TestFlight, not a debug run.

- [ ] Fresh install: onboarding, tour, notification permission.
- [ ] Create a course with two medications and two times.
- [ ] A reminder arrives on the lock screen. **Take**, **Snooze** and **Skip** work without opening the app, and the badge updates.
- [ ] Log, undo, skip on Today. Stock goes down and back up.
- [ ] Diary entry with a photo. A blood-pressure reading.
- [ ] Doctor report PDF: create it and share it.
- [ ] App lock: lock, background, unlock.
- [ ] *Manage your data*: delete the diary only.
- [ ] Settings links open Help & Support, Privacy Policy and Terms of Use.
- [ ] Dark mode, largest Dynamic Type, a quick VoiceOver pass on Today.
- [ ] One non-English language, e.g. Ukrainian.

## 6. Upload to TestFlight

1. Pick **Any iOS Device (arm64)**, then **Product → Archive**.
2. In **Organizer**, choose **Distribute App → TestFlight & App Store**.
3. Wait for the "has completed processing" email (10–30 min).
4. In **TestFlight**, add the build to the testing group. Groups with *Automatic Distribution* get it themselves.
5. **External testers.** The first build of a version goes through Beta App Review, usually within a day. Fill in *What to Test*.

## 7. App Store submission

**(first release)** Set up once in App Store Connect:

- **App Information**:
  - category: Medical or Health & Fitness;
  - content rights;
  - age rating. Answer the medical questions honestly: it is a tracker, not treatment.
- **Support URL**: `https://totsamygaspar.github.io/Plekio/`
- **Privacy Policy URL**: `https://totsamygaspar.github.io/Plekio/privacy-policy.html`
- **License Agreement**: Apple's standard EULA. `terms.md` points to it.
- **Pricing and Availability**: free. Choose the countries.
- **Business → DSA**: trader status for the EU. Without monetization: not a trader.

Every release:

- [ ] **Screenshots**: 6.9" iPhone at least. Only if the UI changed.
- [ ] **Description, keywords, What's New.**
- [ ] **Review notes**: no account needed; all data is local. Mention that the app is a tracker and doesn't give medical advice (Guideline 1.4.1).
- [ ] **Submit** with *Manually release* if you want to choose the day.

## 8. After release

- [ ] Tag the shipped commit and push the tag: `git tag -a v1.0 -m "…"`, then `git push origin v1.0`.
- [ ] Watch *Organizer → Crashes* and App Store Connect reviews for a few days.

## Feature flags

`Plekio/Core/Settings/AppFeatures.swift`:

| Flag | Now | To turn on |
|---|---|---|
| `tips` | off | Paid Apps agreement active (bank and tax). Three consumables in App Store Connect with the ids from `TipSize`, *Ready to Submit*. DSA trader status if shipping in the EU. Tips sections back in `privacy-policy.md` and `terms.md`. Purchase tests run locally on iOS 27: they only run while the flag is on. |

## Known environment issues

- **Xcode 27 on macOS 27 can hang at launch under the debugger.** If Run hangs, turn off *Debug executable* in the scheme locally. Don't commit that change.
- **StoreKitTest purchases never return** on the iOS 26 simulator, and at times on Xcode Cloud. The tip purchase tests skip there with the reason shown.
- **`SKTestTransaction.h` deprecation warning.** It comes from Apple's own header; nothing to fix.
