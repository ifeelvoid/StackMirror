<p align="center"><img src="Assets/StackMirror-Icon-1024.png" width="128" alt="StackMirror icon"></p>

<h1 align="center">StackMirror</h1>

<p align="center">Schedule Substack Notes from your Mac, with a calendar of everything you have scheduled.</p>

> StackMirror is a local tool, not an official Substack client. It uses Substack's undocumented Notes endpoints.

## What it does

- **Calendar** — a month view of your scheduled Notes, read from Substack itself, so Notes scheduled elsewhere show up too. Pick a day, write a Note, choose a time, and schedule it.
- **Composer** — publish a Note now or schedule it.
- **Campaigns** — turn an article into three scheduled promotion Notes: launch, pull quote, and reminder. They appear on the calendar.
- **Analytics, Engagement, Library** — your Note performance, replies, subscriptions, and a reading list, refreshed by a weekly scan.

Scheduled Notes are held by Substack as native scheduled drafts. StackMirror does not need to be running when they publish.

## Safety model

- Your Substack session cookie is stored only in the macOS Keychain, on this device.
- Credentials are never written to project files, app preferences, or logs.
- App state is stored at `~/Library/Application Support/StackMirror/state.json` with owner-only permissions. Unreadable state is never overwritten. See [docs/launch-recovery.md](docs/launch-recovery.md).
- StackMirror never deletes or edits your existing Substack drafts or Notes.
- No API keys, cookies, app state, or build bundles belong in Git.

## Install

1. Download `StackMirror-<version>.dmg` from [Releases](https://github.com/ifeelvoid/StackMirror/releases/latest).
2. Open it and drag **StackMirror** onto **Applications**.
3. The first time, right-click StackMirror in Applications and choose **Open**, then **Open** again.

StackMirror is ad-hoc signed, not notarized by Apple, so macOS asks once before the first launch. If macOS says the app is damaged, run this once:

```bash
xattr -dr com.apple.quarantine /Applications/StackMirror.app
```

Requires macOS 14 or later. The app runs natively on Apple Silicon and Intel.

## Build from source

Requires full Xcode (not only Command Line Tools).

```bash
./script/build_and_run.sh
```

The app bundle is written to `dist/StackMirror.app`. To package a release DMG:

```bash
./script/make_dmg.sh
```

To regenerate the app icon from the glyph in `Assets/StackMirror-AppIcon.png`:

```bash
./script/build_icon.sh
```

## Setup

1. Open StackMirror **Settings** and click **Connect Substack**. Sign in inside StackMirror; the session is saved to the Keychain.
2. Open **Calendar**. Your existing scheduled Notes load from Substack.
3. Select a day, write a Note, pick a time, and click **Schedule**.

## Limitations

- Substack has no documented public Notes API. Endpoints may change without notice. Use at your own risk and review Substack's terms.
- Scheduled Notes cannot yet be rescheduled or unscheduled from StackMirror. Use Substack for that.
- Link previews are created when Substack accepts the URL. A rejected preview does not block the Note text.

## Security

Read [SECURITY.md](SECURITY.md) before reporting a vulnerability.
