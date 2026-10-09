#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p .build
swiftc -parse-as-library Sources/MediaCoder/ConversionEngine.swift Sources/MediaCoder/CodecSupport.swift Sources/MediaCoder/ConverterModel.swift Tests/QueueIntegration.swift -o .build/queue-integration
.build/queue-integration
