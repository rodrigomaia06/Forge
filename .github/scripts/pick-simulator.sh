#!/bin/bash
# Prints the name of the simulator to test on, and appends SIMULATOR_NAME to $GITHUB_ENV.
#
# A large, recent iPhone. Taking whatever came first gave an SE, whose width wraps titles the
# reference screenshots do not.
set -euo pipefail

DEVICES="$(xcrun simctl list devices available -j)"
NAME=""
for WANT in 'iPhone 17 Pro Max' 'iPhone 17 Pro' 'iPhone 16 Pro Max' \
            'iPhone 16 Pro' 'iPhone 15 Pro Max' 'iPhone 15 Pro'; do
  NAME="$(echo "$DEVICES" | jq -r --arg n "$WANT" \
    '[.devices[][] | select(.isAvailable and .name == $n)] | first | .name // empty')"
  [ -n "$NAME" ] && break
done
if [ -z "$NAME" ]; then
  NAME="$(xcrun simctl list devices available | awk -F '[()]' '/iPhone/ {gsub(/^ +| +$/, "", $1); print $1; exit}')"
fi
if [ -z "$NAME" ]; then
  echo "No available iPhone simulator." >&2
  exit 1
fi

echo "$NAME"
if [ -n "${GITHUB_ENV:-}" ]; then
  echo "SIMULATOR_NAME=$NAME" >> "$GITHUB_ENV"
fi
