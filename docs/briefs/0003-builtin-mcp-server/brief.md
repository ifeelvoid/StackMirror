# Build an MCP server into StackMirror

**Serial:** #0003 · **Created:** 2026-11-12T16:38:24Z · **Author:** ifeelvoid@proton.me · **Depends on:** #0002

## Claim

An AI assistant can plan and schedule Substack Notes through StackMirror if the app itself is an MCP server, and users only have to turn it on.

## Desired outcome

- The StackMirror app binary runs as a stdio MCP server when it is started with `--mcp`. There is no separate download or binary.
- Settings has an "AI assistants (MCP)" section with an Enable switch. It is off by default. When it is off, the server lists no tools and refuses tool calls.
- One click adds StackMirror to Claude Desktop's config. The section also shows a copyable command for Claude Code and a JSON snippet for other MCP clients.
- Tools:
  - `list_scheduled_notes`: Substack's scheduled drafts, fetched live.
  - `schedule_note(text, at)`: creates a native scheduled draft, for future times only. It uses the same transform and link-preview settings as the app.
  - `recent_note_stats`: engagement on recent Notes, read from local state.

## Constraints

- The session cookie stays in the Keychain and never appears in tool output.
- The MCP process never writes `state.json`. The app stays the only writer.
- No publish-now tool, and no edit or delete tools.
- Editing the Claude Desktop config merges into it without losing other servers or keys. A file that can't be parsed is refused, not overwritten, and the previous file is backed up first.
- No new package dependencies.

## Settled decisions

- The server is built into the app, not shipped as a separate helper (Alexander, 2026-11-12: "built into the actual program … just enable it").
- There is no publish-now tool (proposal accepted 2026-11-12).

## Risks

- The MCP protocol is hand-rolled (JSON-RPC over stdio, tools only), so a client using a newer protocol version could reject it. Mitigation: negotiate to a supported version.
- The `--mcp` mode must not start the SwiftUI app or show a Dock icon.
- The command path points inside the `.app`. If the user moves the app, the client config breaks. The UI shows the path and warns when the app is outside /Applications.
- A prompt-injected agent could schedule unwanted Notes. Mitigations: the switch is off by default, there is no publish-now, only future times are accepted, and each server session has a cap.

## Acceptance checks

- `swift build` is clean, and `swift test` passes, including new MCP protocol, tool-gating, validation, and config-merge tests.
- A real stdio handshake against the built app binary (initialize, tools/list, and a gated tools/call) returns valid JSON-RPC.
- blc-review-pr passes.
