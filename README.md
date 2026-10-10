# Media Coder

A small, native SwiftUI video converter for macOS 14 or later. Drop videos, choose a format and size, then click Convert. Everything runs locally using FFmpeg.

## Run

Run `make` (or `make all`) to run `make dev`, which calls `make open`: close the running app, set up the build tools, build Release, and launch it.

```sh
make            # setup + dev
make dev        # run make open
make build      # build optimized Release
make open       # close the app, build Release, and launch
make close      # stop this project's Debug and Release app instances
make clean      # remove all local build artifacts
make help       # grouped command reference
```

`make setup` checks for full Xcode and installs XcodeGen via Homebrew if it is missing. Install Xcode and Homebrew first. FFmpeg is optional at build time and can be downloaded from the app.

The Release app lives at `build/Build/Products/Release/MediaCoder.app`. For a Debug build, run the project in Xcode. Xcode automatically updates existing build products, so `make dev` does not delete them first. `make clean` removes `build/`, `.build/`, and local `DerivedData/`; it preserves source files, the project, preferences, and downloaded codec engines. Release builds are optimized local apps; signing/notarization for distribution is a separate step.

`make close` sends a termination signal to native app processes whose executable path exactly matches this project’s Debug or Release app. It does not close other checkouts or installed copies. `make open` (and therefore `make dev`) runs it before building, so finish any conversions before restarting.

For development, you can also open `MediaCoder.xcodeproj` in Xcode or use `swift run`.

## Features

- Drop multiple videos or add them with the file picker (Command-O).
- Input formats include MPG/MPEG, AVI, MOV, MP4, MKV, WMV, WebM, and more; codec support depends on your FFmpeg build. Any readable file can be added, avoiding an extension whitelist that would block obscure formats. FFmpeg validates its contents during conversion.
- Video output presets: H.264 (MP4/MOV/MKV), HEVC and AV1 (MP4), ProRes (MOV), VP8/VP9 (WebM), FFV1 lossless encoding (MKV), MPEG-4 (AVI), MPEG-2 (MPG), Windows Media (WMV), Motion JPEG (MOV), HuffYUV (AVI), and Ut Video (AVI). AV1 automatically uses libaom or SVT-AV1 depending on the active engine. Only presets with the required encoders are shown. Resizing and pixel normalization can change pixels even when using a lossless encoder.
- Extract the first audio track as M4A (AAC), MP3, WAV (PCM), FLAC, Apple Lossless (M4A), Opus, WavPack, AIFF, or AC-3. AC-3 exports stereo at 48 kHz; Opus uses 48 kHz. Choose an option under **Extract audio** in the format menu, then click **Extract audio**. Video size does not apply. Files are named `movie-audio.m4a` (with numeric suffixes to avoid overwriting); videos without audio show an error. WAV and FLAC do not restore quality lost in the source.
- Keep original size or fit within 3840×2160 (4K UHD), 2560×1440 (2K/QHD), 1920×1080, 1280×720, or 854×480. Choose **Custom** to enter width and height bounds from 2 to 16384 pixels, preserving display aspect ratio without upscaling. Dimensions are rounded to even pixels for encoder compatibility. Anamorphic sources are normalized to square pixels.
- Choose **Smaller file**, **Balanced** (default), or **High quality** for destination video. Quality adjusts compression for the selected codec; higher quality generally produces larger files and cannot restore detail absent from the source. FFV1 uses fixed lossless encoding, and audio extraction is unaffected.
- Optional **Hardware acceleration** for H.264 (MP4/MOV/MKV) and HEVC (MP4) uses Apple VideoToolbox when present in the engine. Software encoding remains the default. Hardware quality levels target 4, 8, or 16 Mbit/s; actual size and quality depend on the source. Hardware failures show a retry suggestion with acceleration disabled. This accelerates encoding; decoding and resizing retain the existing path.
- Source specs for the selected video: resolution, video codec, frame rate, duration, overall bitrate, first audio track details, and file size. Read locally using the active engine without converting the file.
- A selectable video sidebar, progress, cancel, retry, error details, and reveal output in Finder. Conversion pauses after each video; click **Next video** to start the next waiting item. Selecting a ready item lets you convert it first.
- Save beside originals or choose a folder. Outputs include the selected size, for example `movie-converted-720p.mp4` or `movie-converted-original.mp4`, with numeric suffixes when needed. The label describes the chosen size preset; smaller sources are never upscaled. Original files are preserved.

The app converts the first video stream and optional first audio stream. Subtitles and additional tracks are not included. It does not remove interlacing. This is a local development build, not a notarized distributable.

## Codec engines and downloads

Open **Settings → Codecs** (Command-comma) to see the active engine, browse/search its actual decoders and encoders, choose a custom FFmpeg executable, or download the portable codec pack. The app remains small because the engine is downloaded separately and reused offline. It does not download video files or upload media.

The portable pack is pinned to the [ffmpeg-static b6.1.1 release](https://github.com/eugeneware/ffmpeg-static/releases/tag/b6.1.1), with native Apple Silicon and Intel downloads (approximately 46 MB and 79 MB respectively). It uses SHA-256 digests pinned in `CodecSupport.swift`, checks HTTP responses, retains the upstream license/README, validates the executable, and moves the complete installation into a versioned folder under `~/Library/Application Support/MediaCoder/Engines/`. Downloads show progress and can be cancelled. Failed/cancelled installs clean up staging files and leave the current engine intact. Already-installed packs are reused.

FFmpeg codecs are compiled into its engine rather than installed as individual plug-ins. The downloadable engine has a broad codec set, but this upstream release contains FFmpeg 6.0 on Apple Silicon and 6.1.1 on Intel, rather than the latest release, and does not promise every codec. A newer/custom engine may support more decoders or different encoders. The codec list reflects the selected engine, including audio and subtitle codecs; this app currently converts video and the first audio track only.

This machine also has a newer Homebrew engine installed. To install or expand a Homebrew engine yourself:

```sh
brew install ffmpeg
# Broader optional library set:
brew install ffmpeg-full
```

Use **Choose engine…** to select that build. The app checks a saved selection, a bundled executable, Homebrew paths, and the downloaded pack. Downloading through the app selects the portable pack; an existing Homebrew installation is never changed by the app. A custom engine can always be selected again.

FFmpeg is not bundled with the app. If distributing an engine or the app commercially, review the selected build's license and provide the required notices/source access. The portable pack's release and pinned digests must be updated together when upgrading.

## Build and verify

Requires full Xcode. `make setup` checks the build tools and installs XcodeGen if needed.

```sh
make build
./scripts/test-engine.sh
./scripts/test-queue.sh
# Also test installation and every available preset with the portable pack:
./scripts/test-engine.sh --download-pack
```

The integration checks create temporary MPG and AVI fixtures and verify real conversions, resizing, silent video handling, malformed input cleanup, cancellation, and existing output protection. The test script currently expects Apple Silicon Homebrew paths.

## App icon

The window header and macOS app icon share `FilmIconArtwork.swift`. PNG assets are checked into `Sources/MediaCoder/Assets.xcassets/AppIcon.appiconset` and compiled into the app by Xcode. To regenerate them after changing the artwork:

```sh
swiftc -parse-as-library Sources/MediaCoder/FilmIconArtwork.swift scripts/generate-app-icon.swift -o /tmp/media-coder-generate-icon
/tmp/media-coder-generate-icon Sources/MediaCoder/Assets.xcassets/AppIcon.appiconset
```
