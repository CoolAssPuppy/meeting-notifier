# Meeting Notifier Pro: Polar subscription

Port the subscription mechanics from `../mail-notifier`. Same shape: Polar
license keys, no server of ours, a normalized entitlement cached locally, and a
gate on extra accounts.

**What is paid.** The first calendar account is free. Accounts two and up are
locked until someone subscribes. This is the direct mirror of Mail Notifier's
gate, and it lands on one filter line in `CalendarDataManager.refreshEvents()`.

**What is removed.** The Venmo "Buy me coffee" row in the Settings contact card.
A subscription and a tip jar in the same drawer is two asks.

**Not in scope.** Gating transcription or AI notes. `PaywallTrigger` is written
as an enum so adding a `transcription` case later is additive.

---

## Chapter 1: What differs from mail-notifier

Five things. Everything else is a file copy plus a rename.

### 1.1 No Secrets.xcconfig

Mail Notifier reads Polar values from `Secrets.xcconfig`, written by
`scripts/pull-polar-secrets.sh` from Doppler. That file needs the `$(SLASH)`
hack because xcconfig treats `//` as a comment and truncates every URL.

Meeting Notifier has no xcconfig. It already passes `POSTHOG_API_KEY` to
`xcodebuild` as a build setting override on the command line, and Info.plist
picks it up through `$(POSTHOG_API_KEY)` substitution. The Polar values ride the
same path.

Consequences, all good:

- No `Secrets.xcconfig`, no `Secrets.xcconfig.example`, no
  `pull-polar-secrets.sh`.
- No `SLASH` hack. A build setting passed on the command line has no comment
  syntax, so `https://buy.polar.sh/...` goes through verbatim.
- `PolarConfig`'s process-environment override still works, so
  `POLAR_ORG_ID=... ./scripts/debug.sh` runs a dev build against sandbox without
  regenerating anything.

### 1.2 Keychain

Mail Notifier depends on the `KeychainAccess` SPM package. Meeting Notifier has
its own `KeychainManager` (`Services/KeychainManager.swift`, service
`com.strategicnerds.meetingnotifier`). Do not add the package. Store the license
key and activation id through `KeychainManager` and inject a protocol so tests
do not touch the real Keychain.

Keep both values out of `KeychainManager.syncableAccounts`. Activation is per
Mac, and the benefit allows five of them, so syncing the key through iCloud
would have two Macs fighting over one activation id.

### 1.3 Entitled accounts are the valid ones, not just the enabled ones

Mail Notifier partitions over enabled accounts. Meeting Notifier has a third
state: `authStatus == .needsAuth`, which is what an account synced from iCloud
looks like on a Mac that has never authorized it. `loadAccounts()` creates those
placeholders.

If the partition runs over enabled accounts alone, a placeholder that has never
fetched anything can eat the one free slot and lock the account the person
actually uses. Partition over accounts that are both `isEnabled` and
`authStatus == .valid`, which is the same predicate `refreshEvents()` already
uses.

### 1.4 Shared UI components need two small additions

`AppPrimaryButton` in Meeting Notifier takes `title: String` and
`systemImage`. It has no `isDisabled` and no `fillsWidth`; the Mail Notifier
version has both, and the paywall uses both. Add them to
`Views/Components/SharedComponents.swift` rather than rewriting the sheet.

Titles are plain `String` here, not `LocalizedStringKey`. Drop the
`LocalizedStringKey(...)` wrappers when porting.

Every theme token the ported views want already exists in `ThemePalette`:
`success`, `warning`, `destructive`, `tertiary`, `cardInset`, `borderStrong`,
`foregroundSoft`, `primaryForeground`.

### 1.5 Formatters

Meeting Notifier's `Services/Formatters.swift` has only `shortTime` and
`weekdayMonthDay`. The port needs three more, copied from Mail Notifier:
`longDate`, `parseISO8601`, and `userMessage(for:)`.

`parseISO8601` matters: Polar sends fractional seconds on some fields and not
others, and `ISO8601DateFormatter` returns nil on the mismatch rather than
tolerating it.

---

## Chapter 2: New files

All paths under `MeetingNotifier/MeetingNotifier/`.

- [x] `Services/PolarConfig.swift` — copy verbatim from mail-notifier, change the
      doc comment's reference to `Secrets.xcconfig` to say the values arrive as
      xcodebuild build settings. Info.plist keys stay `PolarOrgID`,
      `PolarBenefitID`, `PolarCheckoutURL`, `PolarPortalURL`, `PolarAPIBase`.
- [x] `Services/LicenseProvider.swift` — copy verbatim. `LicenseStatus`,
      `LicenseActivation`, `LicenseProvider`, `LicenseError`. No changes.
- [x] `Services/PolarLicenseClient.swift` — copy verbatim. The three
      `v1/customer-portal/license-keys/*` endpoints take no auth. Swap
      `Log.license` for `Logger.license` and add that category to
      `Services/Logger.swift`.
- [x] `Services/EntitlementManager.swift` — copy, then three edits:
      - Replace the `KeychainAccess.Keychain` dependency with a
        `LicenseCredentialStore` protocol (`get`, `set`, `remove`), default
        implementation conforming `KeychainManager` to it.
      - `Telemetry.capture(.entitlementLapsed)` stays, once the event exists.
      - `isEntitledNow()` keeps its `DemoMode` escape hatch only if Meeting
        Notifier has one. It does not, so replace that guard with the existing
        `CommandLine.arguments.contains("--uitesting")` check, which is what the
        screenshot tests rely on.
- [x] `Views/PaywallCopy.swift` — every user-facing word about money. Rewrite
      the copy for this app (draft in Chapter 6). Keep `PaywallTrigger`.
- [x] `Views/PaywallSheet.swift` — copy, drop `LocalizedStringKey` wrappers.
- [x] `Views/Components/SubscriptionCard.swift` — copy, drop
      `LocalizedStringKey` wrappers.

## Chapter 3: Edits to existing files

### Config and build

- [x] `project.yml` — add five keys under `targets.MeetingNotifier.info.properties`,
      next to the PostHog block:

      PolarOrgID: "$(POLAR_ORG_ID)"
      PolarBenefitID: "$(POLAR_BENEFIT_ID)"
      PolarCheckoutURL: "$(POLAR_CHECKOUT_URL)"
      PolarPortalURL: "$(POLAR_PORTAL_URL)"
      PolarAPIBase: "$(POLAR_API_BASE)"

- [x] `xcodegen generate`, then commit the regenerated
      `MeetingNotifier/Info.plist`.
- [x] `scripts/release.sh` — pull the five values from Doppler
      `meeting-notifier/prd` beside the existing `POSTHOG_PUBLIC_KEY` fetch, and
      pass them to both `xcodebuild archive` invocations. Fail the build when
      `POLAR_ORG_ID` is set but `POLAR_BENEFIT_ID` is empty: that combination
      ships a build that sells subscriptions and accepts any Strategic Nerds
      key. `POLAR_API_BASE` must be empty in `prd`, and empty is a valid value,
      so do not treat it as missing.
- [x] `scripts/debug.sh` — optional. Pull from `meeting-notifier/dev` (the
      sandbox values) so a debug build exercises the paywall. Without it, a dev
      build has no Polar config and unlocks every account, which is also a valid
      way to work.

### Plumbing

- [x] `Services/Logger.swift` — add a `license` category.
- [x] `Services/TelemetryEvent.swift` — add six cases, keeping `object_action`
      snake_case:
      `paywall_shown`, `subscribe_clicked`, `license_activated`,
      `license_activation_failed`, `license_removed`, `entitlement_lapsed`.
- [x] `Models/NotificationNames.swift` — add `entitlementChanged` and
      `showPaywall`.
- [x] `Services/Formatters.swift` — add `longDate`, `parseISO8601`,
      `userMessage(for:)`.
- [x] `Views/Components/SharedComponents.swift` — add `isDisabled` and
      `fillsWidth` to `AppPrimaryButton`.

### The gate

- [x] `Services/AppSettings.swift` — add the partition, modeled on Mail
      Notifier's `Accounts` extension but reading `AppSettings.shared.accounts`:

      static let freeAccountLimit = 1

      static func partition(_ accounts: [CalendarAccount],
                            isEntitled: Bool,
                            limit: Int = freeAccountLimit)
          -> (active: [CalendarAccount], locked: [CalendarAccount])

      Pure and static, taking the array as an argument, so it tests without a
      store or a network. Callers pass
      `accounts.filter { $0.isEnabled && $0.authStatus == .valid }`.

      Plus `makeFree(_ account:)`, which moves that account to index 0. The free
      slot goes to the first qualifying account in stored order, so moving to
      the front is how someone picks which calendar stays free.

- [x] `Managers/CalendarDataManager.swift` — the one enforcement point. Line 79
      becomes the partition's `active` list. Everything downstream reads
      `CalendarDataManager.shared.events`: the menu bar, notifications, the
      dropdown, keyboard shortcuts, and the transcription auto-offer. Filtering
      here covers all of them, so no other manager needs a gate.

- [x] `AppDelegate.swift` — three additions:
      - `EntitlementManager.shared.start()` in `applicationDidFinishLaunching`,
        before the first calendar refresh.
      - `addGoogleAccount()` and `addMicrosoftAccount()` check
        `canAddAnotherAccount()` first and post `.showPaywall` with
        `.addAccount` instead of opening the OAuth window.
      - Observe `.entitlementChanged` and trigger a refresh plus a menu bar
        rebuild.
      - A `showPaywall(trigger:)` that raises the main window and posts
        `.showPaywall`.

- [x] `Views/MainView.swift` — host the `PaywallSheet`, listening for
      `.showPaywall`. Mail Notifier hosts it in `MainView` for the same reason:
      it is the only view guaranteed to exist when the notification arrives.

### The paid state in the UI

- [x] `Views/Sidebar.swift` — a "Locked" pill in `SidebarAccountRow.trailing`
      for accounts in the locked partition, matching the existing "OFF" pill.
- [x] `Views/AccountView.swift` — the locked banner: lock icon, two lines of
      copy, a Subscribe button, and "Use this one instead" calling
      `AppSettings.shared.makeFree(account)`.
- [x] `Views/SettingsDrawer.swift` — add `SubscriptionCard()` to the left
      column, above `generalCard`. Remove the Venmo `contactRow` from
      `contactCard`.
- [x] `Views/MainView.swift` (WelcomeView) — no gate needed, the first account
      is free, but route both buttons through the same check so the behavior
      stays in one place.
- [x] `Views/ClassicMenuBuilder.swift` — nothing. Locked accounts contribute no
      events, so the classic menu is already correct.

## Chapter 4: Tests

`MeetingNotifierTests`, XCTest, matching the existing files.

- [x] `EntitlementManagerTests.swift` — the pure statics:
      `isEntitled(record:now:)` across granted, revoked, disabled, unknown, nil,
      expired, and no-expiry. `reduce(current:result:now:)` for the grace rule:
      success replaces, an invalid key lapses immediately, a `URLError` keeps the
      prior record. `secondsUntilNextMidnight(after:in:)`.
- [x] `PolarLicenseClientTests.swift` — `checkStatus` for 200, 404, 403 with an
      activation-limit message, 403 without one, 500. `checkBenefit` for match,
      mismatch, empty pin, and a response with no `benefit_id`. `decodeStatus`
      and `decodeActivation` against fixture JSON. `errorMessage` across the
      three Polar error shapes.
- [x] `AccountEntitlementTests.swift` — `partition` for entitled (nothing
      locked), not entitled with one account, not entitled with three accounts,
      an empty list, and the case that matters here: a `.needsAuth` placeholder
      does not consume the free slot.

Run `xcodebuild test` after each file, not at the end.

## Chapter 5: Manual verification

The full sandbox pass is in `tasks/polar-setup.md`, Chapter 4. The short version
of what must be true before this ships:

1. One account, no subscription, no paywall anywhere.
2. Adding a second account opens the paywall instead of the OAuth window.
3. A sandbox key activates and the second account starts fetching.
4. A Sync Bar sandbox key is rejected as a different product.
5. Offline relaunch keeps a subscriber unlocked.
6. Cancelling in the Polar dashboard locks the second account on the next check.

## Chapter 6: Copy draft

For `PaywallCopy.swift`. Rewrite freely, this is a first pass.

- Plan name: `Meeting Notifier Pro`
- Price minimum: `$1.99`, suggested `$5.99`, yearly, pay what you want
- Sheet subtitle: "Your first calendar is free. Connecting more than one needs a
  subscription."
- Why pay: the Google CASA assessment, same argument as Mail Notifier. The app
  reads calendar data through a restricted Google scope and pays for an annual
  third-party security assessment to keep doing it.
- Name your price: same as Mail Notifier.
- Locked badge: "Locked"
- Locked banner title: "This calendar is paused"
- Locked banner body: "You get one calendar account for free. Subscribe to see
  this one too."
- Make free button: "Use this one instead"

## Chapter 7: One thing to know before starting

**The debug build shares state with the installed app.** Same bundle id, so the
same UserDefaults and the same Keychain. The moment a debug build launches with
no license, the second and third calendar accounts go Locked in the copy in
`/Applications` too. It is reversible, but write a `scripts/test-state.sh` like
Mail Notifier's before the sandbox pass, and back up before touching anything.

Deleting an account through the app UI is not reversible in the same way:
`AppSettings.removeAccount` clears that account's Keychain tokens, and getting it
back costs a full re-authorization. Never use the UI to set up a test.

## Chapter 8: Delete the App Store leftovers

Distribution is Developer ID through Sparkle and R2, and stays that way. Two
files in the repo say otherwise and neither has code behind it. Delete both while
the subscription work is open, so nobody reads them later and thinks in-app
purchase is on the table.

- [x] `MeetingNotifier/Configuration.storekit` — a StoreKit test configuration
      for a $4.99 "Buy Me Coffee" non-consumable. There is no `import StoreKit`
      anywhere in the app, so it configures nothing.
- [x] `MeetingNotifier/APP_STORE_SUBMISSION.md` — a submission walkthrough for
      version 1.0, build 2026. The app is at 1.4.4, build 21.

The `_applicationInternalID` in the storekit file points at a real App Store
Connect record. Deleting the file does not touch that record, so this is
reversible by way of App Store Connect if the plan ever changes.


---

## Review

Built on `polar-implementation`, 12 September 2026. Everything in Chapters 2
through 4 and 8 is done. Chapter 5 (the sandbox pass) needs the Polar product to
exist and is yours to run.

### What shipped

Seven new files, fifteen edited, two deleted. The code compiles with no new
warnings and the suite runs 188 tests.

### Where the plan was wrong

Four things the plan got wrong or left out, all found while building:

**`Formatters` is called `AppDateFormatters`.** The plan said to add three
helpers to `Formatters`. Two went onto `AppDateFormatters` (`longDate`,
`parseISO8601`); `userMessage(for:)` became `Error.userMessage`, an extension,
because it is error presentation and not a formatter.

**The gate statics had to be `nonisolated`.** `AppSettings` is `@MainActor`, so
its static members are too, and the test target could not call `partition` from a
synchronous test. Same for `EntitlementManager.storageKey`. They are pure and
take their input as arguments, so `nonisolated` is what they should have been.

**`AppStatusPillStyle` has no `.warning` case.** It is `.tinted(Color)` and
`.neutral`, so the Locked badge is `.tinted(theme.warning)`.

**`CalendarDataManager` needed a second observer.** The plan listed one
enforcement point and stopped there. Its existing observer watches
`AppSettings.$accounts`, and activating a license changes which accounts may run
without the accounts array changing at all, so the event list would not have
refreshed until something else touched it. Now it also observes
`.entitlementChanged`. `Sidebar` and `AccountView` have the same problem and
solve it by observing `EntitlementManager.shared`.

### What the tests cover

`EntitlementTests` (35 tests): the gate across every license state, the grace
rule (offline and 5xx keep the prior record, a bad key lapses at once), the daily
check, the account partition, and the read path `CalendarDataManager` actually
walks. That last group is the one worth keeping: it drives `isEntitledNow`
through a real `UserDefaults` suite with a Polar org set in the environment, so it
proves an unconfigured build unlocks everything and a configured one with no
license gates the second account.

`PolarLicenseClientTests` (22 tests): HTTP status mapping including the
activation-limit substring match, the benefit pin in all four directions, and
decoding of both response shapes including the fractional-seconds case.

### Verified by hand

- Build settings substitute into Info.plist. Built with a fake org id and read
  the five values back out of the bundle.
- `scripts/test-state.sh` backup, trim to one account, and restore round-trips
  cleanly against the real UserDefaults, with both accounts intact afterwards.
- The app launches with the gate on and leaves no residue: after rebuilding
  without the Polar config, there is no entitlement record and no Keychain entry.
- `./scripts/debug.sh --no-launch` and `--polar` both work. `bash -n` passes on
  all three scripts.

### Not fixed, and not mine

`TranscriptionCoordinatorTests.test_shouldAutoStopForInactivity_whenMicIsActive_returnsFalseEvenPastTimeout`
fails. It fails on `main` too, confirmed by stashing this branch and re-running.
Out of scope here.

### Still open

- The Polar product, benefit, and links, in sandbox and then production.
  `tasks/polar-setup.md` has the steps.
- The five Doppler values in `meeting-notifier/dev` and `meeting-notifier/prd`.
- The 15-test sandbox pass in `tasks/polar-setup.md` Chapter 4. Test 10, the
  cross-app leak, is the one that proves the benefit pin is wired up, and it has
  to be run in both directions.
- The paywall copy in `PaywallCopy.swift` is a first pass, carried over from Mail
  Notifier with the wording changed from inboxes to calendars. Worth a read
  before anyone pays to see it.
