#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"

# Match executable paths exactly, avoiding other apps or checkouts with the same name.
debug_executable="$PWD/build/Build/Products/Debug/MediaCoder.app/Contents/MacOS/MediaCoder"
release_executable="$PWD/build/Build/Products/Release/MediaCoder.app/Contents/MacOS/MediaCoder"
closed=0
while read -r app_pid executable; do
    # Normalize symlinks such as /var → /private/var before comparing.
    executable="${executable:A}"
    if [[ "$executable" == "$debug_executable" || "$executable" == "$release_executable" ]]; then
        if kill -TERM "$app_pid" 2>/dev/null; then
            print "Stopped Media Coder (PID $app_pid)."
            closed=1
        fi
    fi
done < <(ps -axo pid=,comm=)

if (( ! closed )); then
    print 'No running Media Coder app instances from this project.'
fi
