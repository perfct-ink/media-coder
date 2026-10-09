#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
configuration="${1:-Release}"
case "$configuration" in
    Debug|Release) ;;
    *) print -u2 "Usage: $0 [Debug|Release]"; exit 2 ;;
esac
xcodegen generate
xcodebuild -project MediaCoder.xcodeproj -scheme MediaCoder -configuration "$configuration" -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
printf '\nApp: %s/build/Build/Products/%s/MediaCoder.app\n' "$PWD" "$configuration"
