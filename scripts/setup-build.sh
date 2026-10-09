#!/bin/zsh
set -euo pipefail

if ! xcodebuild -version >/dev/null 2>&1; then
    print -u2 'Full Xcode is required. Install Xcode and select it with xcode-select before building.'
    exit 1
fi

if ! command -v xcodegen >/dev/null 2>&1; then
    if ! command -v brew >/dev/null 2>&1; then
        print -u2 'XcodeGen is required. Install Homebrew, then run brew install xcodegen (or install XcodeGen yourself).'
        exit 1
    fi
    brew install xcodegen
fi

print 'Build tools ready. FFmpeg can be downloaded from the app when needed.'
