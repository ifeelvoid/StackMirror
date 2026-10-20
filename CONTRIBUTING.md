# Contributing to StackMirror

StackMirror is a local macOS app. Keep changes small, avoid adding credentials or user content to fixtures, and preserve the read-only contract for source schedulers.

Before opening a pull request, run `swift build` and use `./script/build_and_run.sh --verify` on a supported macOS system. Document any Substack endpoint assumptions in the pull request.

Do not commit `dist/`, `.build/`, local state, session cookies, API keys, provisioning profiles, or private keys.
