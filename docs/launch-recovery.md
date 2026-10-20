# State recovery

Unreadable state blocks startup, scheduling, publishing, and saving. Never delete state.json to silence this error. It holds your settings and cached Substack data, and StackMirror refuses to overwrite it so a recovery stays possible.

The store is `~/Library/Application Support/StackMirror/state.json`. A successful save first preserves the previous valid bytes in `state.json.backup`, then atomically writes state.json. Both files use 0600 permissions. A corrupt current file is preserved rather than overwritten. This is one previous version, not an off-device retention policy.

Quit StackMirror before recovery. Preserve both files in private storage, check that the backup is valid JSON, and restore a verified copy atomically. Then restart StackMirror. Scheduled Notes live in Substack, not in this file, so restoring a backup cannot duplicate or lose a scheduled Note; the calendar reloads them from Substack.

Isolated fixtures verify first run, corruption refusal, backup bytes, restored state, and loading state written by earlier mirroring versions.
