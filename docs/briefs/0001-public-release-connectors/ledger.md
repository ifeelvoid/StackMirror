# Ledger — Ship StackMirror securely with additional scheduler sources

`blc/2 #0001 in-progress a:in-progress b:pending c:pending d:pending`

**Brief:** `docs/briefs/0001-public-release-connectors/brief.md`
**Status:** in-progress
**Created:** 2026-09-27

## Phases

- **a — release hardening** — audit credential handling, remove unsafe behavior, add public-repo hygiene and release documentation. **Status:** in-progress on `brief/0001-a-release-hardening`. **Depends on:** none.
- **b — source adapter core** — normalize source identity, safe endpoint validation, credentials, response/error handling, and test seams. **Status:** in-progress on `brief/0001-a-release-hardening`; pulled into the same branch because the existing Postiz work required the shared source identity repair. **Depends on:** a.
- **c — scheduler adapters** — add Typefully, Publer, and Mastodon read-only scheduled-post adapters and explicit setup UX. **Status:** in-progress on `brief/0001-a-release-hardening`; pulled into the same branch to keep the security contract consistent across every API connector. **Depends on:** b.
- **d — verification and publication** — build, test, scan, blocking review, commit, create public GitHub repository, push, and validate the remote. **Status:** pending. **Depends on:** a, b, c.

## Dependency structure

`a → b → c → d` is a strict chain. The release hardening phase establishes the security boundary and public-source rules before new credentials or endpoints are introduced.

## Decisions

- Implement documented, read-only source APIs only: Typefully, Publer, and Mastodon.
- StackMirror will never schedule, edit, or publish back to a source scheduler.
- Publer requires a Business account; this is an eligibility requirement, not a fallback claim.
- MIT is approved for this public release.

## Complications

- The repository has no `tools/orient.sh`; orientation used the root source and Git state instead.
- Two existing source files are modified from prior work and will be preserved and reviewed as part of the release scope.
- Live third-party API validation needs user-provided test credentials, so non-destructive unit/build validation is required before publication and live validation remains a documented gap.

## Execution log

- 2026-09-29: Started phase a on `brief/0001-a-release-hardening`. Removed the source-code Postiz fallback, restored Keychain-only credential lookup, and began source-model/persistence repairs required for the existing Buffer/Postiz integration. No live credential or third-party API call was made.
- 2026-09-29: Verified the repaired non-UI source set with `swiftc -typecheck`; a repository secret-pattern scan found no 40+-character hexadecimal values outside documentation/build output. Full `swift build` no longer reports the missing `ScheduledPost` or source/persistence type errors, but remains blocked by the installed Command Line Tools missing the `SwiftUIMacros` plugin. Current upstream Postiz source confirms `GET /public/v1/posts` returns a `{ posts }` envelope for the supplied date range; StackMirror now accepts only its `QUEUE` scheduled state.
- 2026-10-12: MIT approved. Phase a hardened Keychain replacement semantics (update-before-insert, device-only accessibility), added release ignore rules, and added public security and contribution guidance. No live credentials were read or sent.
- 2026-10-12: Typefully, Publer, and Mastodon source adapters were added as opt-in read-only sources. Source identities now include their provider, so provider-local IDs cannot collide. Typefully's queue only exposes previews, so the adapter reads the documented draft-detail endpoint for text; Publer requires a Business API workspace; Mastodon requires a plain HTTPS instance URL and a `read:statuses` token. Core source type-check passed. Full app build and test remain blocked before project compilation because this Mac has Command Line Tools but no `SwiftUIMacros` plugin from full Xcode.
- 2026-10-18: Phase d readiness audit. Full Xcode is now selected, but `swift build` stops at the unaccepted Xcode license, so build and tests remain unverified. A pattern scan of all Git history found no hardcoded credentials; the removed Postiz fallback was never committed. Release blockers found: `VoidPackBuilder.swift` and `VoidPacksView.swift` are a personal IFEELVOID tool with hardcoded personal local paths and IFEELVOID licensing text, and those paths are also in commit `13a2d1c`. `.codex/` is tracked. `PersistenceSafetyTests.swift` and `docs/launch-recovery.md` are untracked. No dedicated secret scanner (gitleaks/trufflehog) is installed.
- 2026-10-18: Decision (Alexander): remove Void Packs from the public app and publish from a fresh single-commit history; the existing private branches keep the full history. Removed `VoidPackBuilder.swift`, `VoidPacksView.swift`, the `voidPacks` sidebar case, and its view route. Untracked `.codex/` and ignored `.claude/` and `.codex/`. A scan of shippable files found no credential patterns or personal local paths; the remaining identifiers (bundle ID `net.ifeelvoid.StackMirror` and the SECURITY.md contact) are intentional. Build and tests are still blocked by the unaccepted Xcode license. No commit, branch, or remote action has been taken.
- 2026-10-20: blc-review-pr on the uncommitted release diff gave **Request changes**. Build and tests did not run: `xcode-select` points at Command Line Tools, and `/Applications/Xcode.app` still reports an unaccepted license. Findings: (1) `PublerPost` gets its `CodingKeys` from a private extension in `PublerAPIClient.swift`, so the `scheduled_at` mapping is probably not used, or the build fails; (2) the Typefully social set ID goes into the URL path without validation; (3) there are no decoding tests for the Publer, Typefully, or Mastodon response shapes. No commit, branch, or remote action has been taken.
- 2026-10-20: Addressed the review findings. Publer now decodes through a private wire type with `scheduled_at` mapping, so the persisted `PublerPost` encoding is unchanged. The Typefully social set ID must be numeric and the Publer workspace ID must contain only identifier characters (`ConnectorEndpoint`). Added internal `decode` seams and `ConnectorDecodingTests.swift` with fixture JSON for Publer, Mastodon, and Typefully, malformed-response cases, and ID validation. These changes have not been compiled or run yet: the Xcode license command is waiting for the password.
- 2026-10-20: Toolchain fixed (`xcode-select` set to Xcode, license accepted). The first full compile exposed a pre-existing `QueueView` error: the view still used the removed `post.text` / `post.dueAt` names. It now uses `postText` / `postDueAt`. `swift build` is clean and `swift test` passes 13/13. `script/build_and_run.sh` launches the app. The built binary contains no "Void Pack" strings and no personal paths. Screen verification was declined, so the UI was not inspected visually.
- 2026-10-20: blc-review-pr re-run gave **Approve with suggestions**, scoped to what was verified. Open items: (1) the provider fixture JSON follows the documented shapes, not captured live responses; Publer numeric IDs or Mastodon null `params.text` would make that source fail closed. (2) The `AppStore` state-recovery gate has no direct test; `PersistenceService` enforces the same no-overwrite rule and is tested. A test exemption for v1 needs Alexander's acknowledgment before publication. (3) Live interoperability with all five sources is still untested.
