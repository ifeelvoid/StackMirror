#!/usr/bin/env bash
# Builds a release StackMirror.app and packages it as dist/StackMirror-<version>.dmg
# with an Applications shortcut for drag-to-install.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${STACKMIRROR_VERSION:-1.0.0}"
export STACKMIRROR_VERSION="$VERSION"
DMG="$ROOT_DIR/dist/StackMirror-$VERSION.dmg"
WORK="$(mktemp -d)"
STAGE="$WORK/stage"
mkdir "$STAGE"
trap 'rm -rf "$WORK"' EXIT

"$ROOT_DIR/script/build_and_run.sh" --build-only

cp -R "$ROOT_DIR/dist/StackMirror.app" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp "$ROOT_DIR/Assets/StackMirror.icns" "$STAGE/.VolumeIcon.icns"

rm -f "$DMG"
hdiutil create -volname "StackMirror $VERSION" -srcfolder "$STAGE" -fs HFS+ -size 32m \
  -format UDRW -ov "$WORK/rw.dmg" >/dev/null
# Mark the volume so Finder shows the StackMirror icon on the mounted disk.
MOUNT="$(hdiutil attach -nobrowse -noautoopen "$WORK/rw.dmg" | awk -F'\t' '/\/Volumes\//{print $NF}')"
SetFile -a C "$MOUNT" 2>/dev/null || true
hdiutil detach "$MOUNT" -quiet
hdiutil convert "$WORK/rw.dmg" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
codesign --force --sign - "$DMG"

shasum -a 256 "$DMG" | tee "$DMG.sha256"
echo "Wrote $DMG"
