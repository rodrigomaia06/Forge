#!/usr/bin/env bash
# Extract PNG screenshot attachments from an Xcode-16 .xcresult bundle.
# Xcode 16 stores result blobs as zstd frames; UI screenshots are XCTAttachment PNGs.
#
# Usage: scripts/extract-screenshots.sh <xcresult-dir> [output-dir]
#   e.g. scripts/extract-screenshots.sh testing-results/3a34358 testing-results/3a34358
set -euo pipefail
XCRESULT="${1:?path to .xcresult dir}"
OUT="${2:-$XCRESULT}"
mkdir -p "$OUT"
n=0
for blob in "$XCRESULT"/Data/data.0~*; do
  [ -e "$blob" ] || continue
  tmp="$(mktemp)"
  if zstd -d -q -f "$blob" -o "$tmp" 2>/dev/null && [ "$(head -c8 "$tmp" | od -An -tx1 | tr -d ' \n')" = "89504e470d0a1a0a" ]; then
    cp "$tmp" "$OUT/screenshot-$n.png"
    n=$((n+1))
  fi
  rm -f "$tmp"
done
echo "Extracted $n PNG(s) to $OUT/"
