# Make StackMirror a Substack Notes scheduler with a calendar

**Serial:** #0002 · **Created:** 2026-10-20T05:09:02Z · **Author:** ifeelvoid@proton.me · **Depends on:** #0001

## Claim

StackMirror is clearer and safer as a public app if it schedules Substack Notes directly and shows them on a calendar, not mirroring other schedulers.

## Desired outcome

- The main screen is a month/week calendar of scheduled Notes. Each Note appears on its scheduled date and time.
- From the calendar or Composer, a user writes a Note, picks a date and time, and schedules it. They can also publish now.
- Scheduling uses Substack's native scheduled drafts (`POST /api/v1/comment/draft` with `triggerAt`). Substack holds the schedule, so the app does not need to run at publish time.
- The calendar shows Substack's actual scheduled drafts, fetched with `drafts(sessionCookie:)`, not only Notes this app created.
- Campaigns still create their three promotion Notes as native scheduled drafts, and those Notes appear on the calendar.
- Analytics, Engagement, and Library stay as they are.
- All source mirroring is removed: the Buffer, Postiz, Typefully, Publer, and Mastodon clients, their settings, Keychain keys, polling, the marker rule, provider-qualified dedupe, and the Mirror Queue.
- README, Overview, and ConnectorKind describe the app as a scheduler. The public single-commit branch is rebuilt from the result.

## Constraints

- The Substack session cookie stays Keychain-only. No new credentials are introduced.
- Persisted state from earlier versions must still load. Removed fields are ignored, not fatal. The no-overwrite and backup rules from #0001 stay.
- Do not delete Substack drafts or Notes as a side effect. Any edit or unschedule action is explicit and user-initiated.
- The scope stays inside this app. No Substack feature that is not already reachable through the existing client.

## Settled decisions

- Mirroring is removed entirely, not kept as an optional import (Alexander, 2026-10-20).
- Analytics, Engagement, Campaigns, and Library are kept (Alexander, 2026-10-20).
- Void Packs stays removed (#0001).

## Open decisions

- Can an existing scheduled draft be rescheduled or unscheduled from the calendar? This depends on whether the existing client or a verified Substack endpoint supports it. If neither does, v1 is view and create only.
- Default calendar view: month or week.

## Risks

- Substack's draft and Notes endpoints are undocumented and may change. Decoding must fail safely, and the README must keep the disclosure.
- Removing the source models changes the `PersistedState` shape. Old `state.json` files must decode with the removed fields ignored.
- Live scheduling cannot be verified without a real Substack session. Fixture tests cover decoding and calendar grouping only.

## Acceptance checks

- `swift build` is clean and `swift test` passes, including new tests for calendar date grouping, draft decoding with `trigger_at`, and loading a pre-pivot `state.json` fixture.
- No source-connector code, settings, or Keychain keys remain (`git grep` for Buffer, Postiz, Typefully, Publer, Mastodon, and marker returns only changelog or brief history).
- The app launches with Calendar as the default screen, and a scheduled draft fixture renders on its date.
- blc-review-pr passes before the public branch is rebuilt.
