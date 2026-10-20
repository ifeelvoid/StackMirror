# Ship StackMirror securely with additional scheduler sources

**Serial:** #0001 · **Created:** 2026-09-27T20:01:37Z · **Author:** ifeelvoid@proton.me · **Depends on:** —

## Claim

StackMirror can be made safe to publish as a macOS source project while preserving its local-first credential model and adding read-only source connectors for documented scheduler APIs.

## Desired outcome

- A public-ready repository with clear setup, limitations, security policy, license, and ignored generated artifacts.
- Existing Buffer and Postiz integrations hardened and covered by tests where practical.
- Read-only scheduled-post source support for Typefully, Publer, and Mastodon.
- Credentials remain only in the macOS Keychain; no scheduler source is modified or published to by StackMirror.
- A verified Swift build and a blocking release review before publication.

## Constraints

- Do not log, serialize, or commit credentials, session cookies, or user content unnecessarily.
- Use only documented APIs and least-privilege, user-supplied access tokens.
- Preserve uncommitted user work unless it is directly required for this release.
- Publer support must identify its Business-plan requirement.
- StackMirror consumes source schedules; it must not alter or submit scheduler posts.

## Risks

- Typefully and Publer response shapes may change; adapter decoding must fail safely.
- Mastodon is instance-hosted, so user-provided instance URLs must be validated as HTTPS endpoints before requests.
- Substack Notes publishing is an undocumented endpoint and must be clearly disclosed.
- A source build alone cannot prove live scheduler interoperability without the user's credentials and test accounts.

## Evidence

- Buffer and Postiz clients already exist, and secrets are stored through `KeychainService`.
- Typefully documents a queue endpoint for scheduled drafts; Publer documents `GET /posts?state=scheduled`; Mastodon documents `GET /api/v1/scheduled_statuses` with read-only `read:statuses` OAuth scope.

## Acceptance checks

- No secret-like files are tracked and a repository secret scan passes.
- `swift build` succeeds and targeted adapter tests pass.
- The UI exposes explicit setup requirements and does not permit unsafe endpoint schemes.
- Git history, README, license, and ignore rules are appropriate for a public repository.
