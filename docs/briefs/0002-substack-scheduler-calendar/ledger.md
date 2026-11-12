# Ledger — Make StackMirror a Substack Notes scheduler with a calendar

`blc/2 #0002 done a:done b:done c:done`

**Brief:** `docs/briefs/0002-substack-scheduler-calendar/brief.md`
**Status:** done
**Created:** 2026-10-20

## Phases

- **a — remove mirroring** — delete the Buffer, Postiz, Typefully, Publer, and Mastodon clients, the `SourcePost`/`MirrorRecord` models, polling, local delivery scheduling, the marker rule, mirror settings and Keychain keys, the Mirror Queue, Overview, and Activity views, and their tests. `PersistedState` and `AppConfiguration` must still decode pre-pivot `state.json`. **Status:** done on `brief/0002-a-remove-mirroring`. **Depends on:** #0001 (branch `brief/0001-a-release-hardening`, commit `47ab086`).
- **b — calendar** — add a month calendar of Substack scheduled drafts as the default screen, with a refresh that fetches drafts. Composing from a selected day schedules a native draft. Campaign Notes appear through the same drafts list. **Status:** done on `brief/0002-a-remove-mirroring`. **Depends on:** a.
- **c — release** — README, menu bar, and settings copy for a scheduler; tests for calendar grouping, draft `trigger_at` decoding, and legacy state; build, test, launch, blc-review-pr, and rebuild `public/main`. **Status:** done on `brief/0002-a-remove-mirroring`. **Depends on:** b.

## Dependency structure

`a → b → c` is a strict chain. All three phases edit `AppStore.swift`, `AppModels.swift`, and `ContentView.swift`, so parallel branches would conflict. Local execution runs all phases on `brief/0002-a-remove-mirroring`. No push and no main-branch ledger commit was authorized.

## Decisions

- Open decision "reschedule/unschedule from the calendar": v1 is view and create only. `SubstackAPIClient` has no draft update or delete call, and adding an unverified endpoint is outside scope. Blocks: nothing in v1.
- Open decision "default view": month (Alexander's default via this run's instructions).
- Overview, Mirror Queue, and Activity are removed because they only report mirroring state. Calendar replaces Overview as the home screen.

## Complications

- `drafts` is refreshed only by the weekly `scanManager()`. Phase b needs a direct draft refresh for the calendar.
- `ContentTransformer` and `ContentTemplate` serve both mirroring and the Composer. They stay; only marker handling goes.
- The menu bar icon and status derive from mirror sync state and must be redefined in phase c.
- No `tools/orient.sh` exists. Orientation used Git state and the source tree.

## Execution log

- 2026-10-20: Brief filed as #0002 from Alexander's direction: "it should just be a substack scheduler with a calender". Mirroring removal and the kept screens (Analytics, Engagement, Campaigns, Library) were confirmed by Alexander. Branch `brief/0002-a-remove-mirroring` was cut from `47ab086`. `public/main` (`c0bf61d`) is now stale and will be rebuilt in phase c.
- 2026-10-20: Phase a done. Deleted the five source clients, `MirrorRules`, the Queue, Overview, and Activity views, and the connector tests. Moved `APIClientError` into its own file, renamed `ConnectorService.swift` to `CSVExportService.swift`, and reduced `CredentialKey` to the Substack session. `AppStore` dropped polling, local delivery, records, and dedupe, and gained `refreshDrafts()` and `scheduledDrafts`. `AppConfiguration` and `PersistedState` decode older files and ignore the mirroring keys.
- 2026-10-20: Phase b done. `CalendarGrid` (pure) builds locale-aware month cells and groups drafts by local day. `CalendarView` is the default screen: a month grid, a day panel with that day's Notes, and a "Schedule a Note" form that creates a native Substack scheduled draft. It refreshes drafts on first open and from the toolbar, the menu bar, and ⌘R.
- 2026-10-20: Phase c done. README, SECURITY, CONTRIBUTING, and launch-recovery now describe the scheduler. `swift build` is clean and `swift test` passes 7/7: calendar padding for Sunday- and Monday-first locales, day grouping across the UTC/New York boundary, `trigger_at` decoding, ISO dates, pre-pivot `state.json` loading, and two persistence-safety tests. The app launched with Calendar as home. The binary has no Mirror Queue, mirroring, or Buffer strings. A live Substack schedule was not exercised.
- 2026-10-20: blc-review-pr on the pivot diff (33 files, +563/−1930) gave **Approve with suggestions**, scoped to what was verified. Couldn't verify: whether `/api/v1/feed/drafts` drops published Notes from the list (if it keeps them, past days show them as scheduled), and whether the UI renders correctly (screen access was declined). Your call: (1) Composer's existing "Test Connection" publishes a real public Note; (2) Keychain items saved for the removed providers stay on this Mac, because StackMirror deletes nothing by design; (3) local mirror-queue records with state `scheduled` are dropped at the next save and were never sent; (4) the `AppStore` recovery-gate test exemption from #0001 still needs acknowledgment.
- 2026-11-12: Alexander authorized publication: he skipped the live test and accepted the AppStore recovery-gate test exemption. Created public repo https://github.com/ifeelvoid/StackMirror and pushed only `public/main` (`71c9cb2`, single parentless commit, tree identical to `brief/0002-a-remove-mirroring`) as `main`. A pre-push scan of that tree found no credential patterns, personal paths, or build/agent directories. No private branch or history was pushed. Live Substack scheduling remains untested.
- 2026-11-12: Release packaging (Alexander: "put releases like a DMG", "make sure the icon looks fine", "properly branded"). The old icon was an opaque white square with no alpha. `script/make_icon.swift` and `script/build_icon.sh` now render the original glyph in white on a dark macOS-grid tile with transparent corners and regenerate `StackMirror.icns`. The icon was checked visually at 256 and 32 px. `Info.plist` now has version 1.0.0 (build 1), a copyright line, and an app category. The release build is universal (arm64 + x86_64). `script/make_dmg.sh` produces `dist/StackMirror-1.0.0.dmg` with an Applications link, a volume icon, a verified checksum, and a SHA-256 file. Installing from the mounted DMG launched the app. There is no Developer ID certificate, so the app is ad-hoc signed and not notarized; the README documents the first-launch step. Tests pass 7/7.
