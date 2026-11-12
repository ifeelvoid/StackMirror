#!/usr/bin/env bash
# Regenerates Assets/StackMirror.icns from the glyph source.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
swift "$ROOT_DIR/script/make_icon.swift" "$ROOT_DIR/Assets/StackMirror-AppIcon.png" "$WORK/icon-1024.png"
mkdir "$WORK/StackMirror.iconset"
for size in 16 32 128 256 512; do
  sips -z $size $size "$WORK/icon-1024.png" --out "$WORK/StackMirror.iconset/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) "$WORK/icon-1024.png" --out "$WORK/StackMirror.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$WORK/StackMirror.iconset" -o "$ROOT_DIR/Assets/StackMirror.icns"
cp "$WORK/icon-1024.png" "$ROOT_DIR/Assets/StackMirror-Icon-1024.png"
echo "Wrote Assets/StackMirror.icns"
