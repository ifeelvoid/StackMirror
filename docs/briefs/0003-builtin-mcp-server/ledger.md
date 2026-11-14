# Ledger — Build an MCP server into StackMirror

`blc/2 #0003 done a:done`

**Brief:** `docs/briefs/0003-builtin-mcp-server/brief.md`
**Status:** done
**Created:** 2026-11-12

## Phases

- **a — built-in MCP:** the `--mcp` stdio mode, the tools, the Settings switch, client setup, tests, and docs. **Status:** done on `brief/0003-a-builtin-mcp`. **Depends on:** #0002 (`70ba5bf`).

## Decisions

- The JSON-RPC layer is hand-rolled instead of using the official Swift MCP SDK. The server needs only initialize, ping, tools/list, and tools/call over stdio. A hand-rolled layer keeps the app dependency-free and makes it fully unit-testable.
- The switch is read from `state.json` on each request, so turning it off in the app takes effect right away without restarting the client.

## Execution log

- 2026-11-12: Brief filed as #0003 from Alexander: "built into the actual program … just enable it". Branch `brief/0003-a-builtin-mcp` was cut from `70ba5bf`, which itself commits the pending #0002 ledger line.
- 2026-11-12: Phase a done.
  - The app binary serves MCP over stdio when started with `--mcp`. The `StackMirrorMain` entry point takes this path before SwiftUI starts.
  - Tools: `list_scheduled_notes`, `schedule_note`, `recent_note_stats`. There is no publish-now, edit, or delete tool.
  - The Settings "AI Assistants" tab has the Enable switch (off by default, saved immediately), "Add to Claude Desktop" (a merge that keeps the other keys, makes a backup, and refuses a config it can't parse), and copy buttons for the Claude Code command and a generic JSON snippet. It warns when the app is outside /Applications.
  - The link-preview attachment logic moved to `SubstackAPIClient.linkPreviewAttachments` so the app and the MCP server share it. Each session has a cap of 20 schedules.
  - `swift build` is clean, and `swift test` passes 20/20, including 13 new MCP and config-merge tests.
  - A real stdio session against the universal 1.1.0 release bundle returned valid JSON-RPC for initialize, tools/list (empty while the switch is off), a refused tools/call, and ping. The process exited 0 in 0.28 s with no window.
  - With a temporary `CFFIXED_USER_HOME` and the switch on, the session listed 3 tools, returned fixture stats, and rejected a past time.
  - The GUI still launches normally.
- 2026-11-12: blc-review-pr on the staged diff (15 files, +913/−13) returned **Approve with suggestions**. Couldn't verify:
  - a live Keychain read and Substack call from a client-launched `--mcp` process;
  - how the Settings tab looks, because screen access was not granted.

  Your call: turning the MCP switch on or off also saves any unsaved edits on the General tab.

  At that point it was not pushed or released.
- 2026-11-13: Alexander authorized release ("Ship v1.1.0").
  - Fixed `script/make_dmg.sh` so the `.sha256` file lists only the file name (private commit `9df2f45`). The v1.0.0 checksum file contains the full local build path, which names the external drive; that asset was not changed.
  - Built `StackMirror-1.1.0.dmg` (universal, ad-hoc signed, not notarized). hdiutil verify passed, the mounted app reports 1.1.0, and `--mcp` answers from inside the DMG.
  - The pre-push scan found no personal paths or credentials; the only matches were the cookie-header template in code.
  - Pushed public commit `01822e3` (same tree as private `9df2f45`, parent `51b833e`) to `main` and published release v1.1.0 with the DMG and its SHA-256 file. The re-downloaded DMG passes `shasum -c`.
  - Live MCP scheduling through a real client remains unverified.
