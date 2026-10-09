#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p .build
swiftc -parse-as-library Sources/MediaCoder/ConversionEngine.swift Sources/MediaCoder/CodecSupport.swift Tests/EngineIntegration.swift -o .build/engine-integration
.build/engine-integration "$@"
