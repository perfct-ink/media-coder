# AGENTS.md — Media Coder

Media Coder is a native SwiftUI video converter for macOS 14+ that runs FFmpeg locally. See [README.md](README.md) for features and build behaviour.

## Commands

- `make` / `make dev` / `make open`: quit this project's app, build Release, and launch it.
- `make setup`: check for full Xcode and install XcodeGen if missing.
- `make build`: Release build at `build/Build/Products/Release/MediaCoder.app`.
- `make close`: quit only this checkout's Debug/Release app. `make clean`: remove build output.
- Tests (no `make test`): `scripts/test-engine.sh` (FFmpeg engine integration) and `scripts/test-queue.sh` (queue logic).
- `swift run` also works for quick debugging.

## Layout

- `Sources/MediaCoder/ConversionEngine.swift`: builds and runs FFmpeg commands.
- `Sources/MediaCoder/CodecSupport.swift`: detects available encoders and decides which presets to show.
- `Sources/MediaCoder/ConverterModel.swift`: the queue and conversion state.
- `Sources/MediaCoder/*View.swift`: SwiftUI UI.
- `Tests/`: standalone integration programs compiled by the scripts above.
- `project.yml`: XcodeGen spec for `MediaCoder.xcodeproj`.

## Conventions

- When a test script compiles an explicit file list and you split or add an engine/model file, add it to that script too.
- Never overwrite or delete the user's source videos. Outputs get numeric suffixes instead of replacing files.
- Only show presets whose encoders the active FFmpeg engine supports.
- Keep README's feature list in sync with behaviour changes.

## Design principles

Follow the [design principles](docs/rules/design-principles.md) for any UI work.

## After changing code

1. `scripts/test-queue.sh` and `scripts/test-engine.sh` when you touched the queue or the engine.
2. `make dev`

Commit messages are one short, imperative line, like the existing history.
