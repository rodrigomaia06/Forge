#!/bin/bash
# Selects the newest Xcode on the runner. Xcode 26 gives the iOS 26 SDK, so the native UI adopts
# Liquid Glass on iOS 26 devices. The deployment target stays iOS 17.
set -euo pipefail

XPATH="$(ls -d /Applications/Xcode_*.app 2>/dev/null | sort -V | tail -1)"
if [ -z "$XPATH" ]; then
  echo "No Xcode_*.app on this runner; using whatever xcode-select already points at."
  xcodebuild -version
  exit 0
fi
echo "Selecting $XPATH"
sudo xcode-select -s "$XPATH"
xcodebuild -version
