import Foundation

@main
struct EngineIntegration {
    static func command(_ executable: String, _ arguments: [String]) throws -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: executable)
        p.arguments = arguments
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        try p.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { throw ConversionFailure(message: "Command failed: \(arguments)") }
        return String(decoding: data, as: UTF8.self)
    }

    static func qualityComparison(ffmpeg: String, source: URL, folder: URL) async throws -> (Int, Int) {
        var sizes: [Int] = []
        for quality in [VideoQuality.smaller, .high] {
            let output = folder.appendingPathComponent(UUID().uuidString + ".mp4")
            try await ConversionEngine().convert(executable: URL(fileURLWithPath: ffmpeg), source: source, destination: output, format: .mp4, size: .original, quality: quality) { _ in }
            sizes.append(try output.resourceValues(forKeys: [.fileSizeKey]).fileSize!)
        }
        return (sizes[0], sizes[1])
    }

    static func main() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("media-coder-test-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let ffmpeg = "/opt/homebrew/bin/ffmpeg"
        let probe = "/opt/homebrew/bin/ffprobe"
        let mpg = folder.appendingPathComponent("sample space.mpg")
        let avi = folder.appendingPathComponent("silent.avi")
        let anamorphic = folder.appendingPathComponent("anamorphic.avi")
        _ = try command(ffmpeg, ["-f", "lavfi", "-i", "testsrc2=size=1280x720:rate=24", "-f", "lavfi", "-i", "sine=frequency=440", "-t", "1", "-c:v", "mpeg2video", "-c:a", "mp2", mpg.path])
        _ = try command(ffmpeg, ["-f", "lavfi", "-i", "testsrc2=size=320x240:rate=24", "-t", "1", "-c:v", "mpeg4", avi.path])
        _ = try command(ffmpeg, ["-f", "lavfi", "-i", "testsrc2=size=720x480:rate=24", "-vf", "setsar=8/9", "-t", "1", "-c:v", "mpeg4", anamorphic.path])
        for (source, format, size, expected) in [(mpg, OutputFormat.mp4, VideoSize.small, "854,480"), (avi, .mov, .hd, "320,240"), (avi, .webm, .original, "320,240"), (anamorphic, .mp4, .original, "640,480")] {
            let output = folder.appendingPathComponent(UUID().uuidString).appendingPathExtension(format.fileExtension)
            try await ConversionEngine().convert(executable: URL(fileURLWithPath: ffmpeg), source: source, destination: output, format: format, size: size) { _ in }
            let dimensions = try command(probe, ["-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height", "-of", "csv=p=0", output.path]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard dimensions == expected else { throw ConversionFailure(message: "Unexpected dimensions: \(dimensions)") }
            print("PASS \(source.pathExtension) → \(format.rawValue), \(dimensions)")
        }
        let large = folder.appendingPathComponent("large.mkv")
        _ = try command(ffmpeg, ["-f", "lavfi", "-i", "color=size=4096x2304:rate=1", "-frames:v", "1", "-c:v", "ffv1", large.path])
        for (source, size, bounds, expected) in [
            (large, VideoSize.twoK, (641, 359), "2560,1440"),
            (large, .fourK, (641, 359), "3840,2160"),
            (mpg, .custom, (641, 359), "638,358"),
            (avi, .custom, (1920, 1080), "320,240"),
            (avi, .fourK, (1920, 1080), "320,240")
        ] {
            let output = folder.appendingPathComponent(UUID().uuidString + ".mp4")
            try await ConversionEngine().convert(executable: URL(fileURLWithPath: ffmpeg), source: source, destination: output, format: .mp4, size: size, customDimensions: bounds) { _ in }
            let dimensions = try command(probe, ["-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height", "-of", "csv=p=0", output.path]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard dimensions == expected else { fatalError("Unexpected dimensions for \(size): \(dimensions)") }
            print("PASS \(size.rawValue): \(dimensions)")
        }
        do {
            _ = try VideoSize.custom.filter(customDimensions: (0, 100))
            fatalError("Invalid custom bounds accepted")
        } catch is ConversionFailure { print("PASS invalid custom bounds") }
        let specs = try await SourceSpecs.inspect(executable: URL(fileURLWithPath: ffmpeg), source: mpg)
        assert(specs.resolution == "1280 × 720")
        assert(specs.video.contains("mpeg2video"))
        assert(specs.frameRate == "24 fps")
        assert(specs.audio.contains("mp2"))
        assert(specs.duration != "Unknown" && specs.fileSize != "Unknown")
        let silentSpecs = try await SourceSpecs.inspect(executable: URL(fileURLWithPath: ffmpeg), source: avi)
        assert(silentSpecs.audio == "No audio track")
        do {
            _ = try SourceSpecs.parse("Invalid data found when processing input", bytes: 10)
            fatalError("Invalid source specs accepted")
        } catch is ConversionFailure { }
        print("PASS source specs, silent audio, and unreadable input")
        let tiny = folder.appendingPathComponent("all-codecs.avi")
        _ = try command(ffmpeg, ["-f", "lavfi", "-i", "testsrc2=size=160x120:rate=25", "-f", "lavfi", "-i", "sine=frequency=440", "-t", "0.3", "-c:v", "mpeg4", "-c:a", "pcm_s16le", tiny.path])
        var engines = [URL(fileURLWithPath: ffmpeg)]
        if CommandLine.arguments.contains("--download-pack") {
            let pack = try await CodecPack.install { _ in }
            engines.append(pack)
            print("PASS pack download, checksum, installation, and inspection")
        }
        for executable in engines {
            let capabilities = try await CodecCapabilities.inspect(executable)
            guard capabilities.decoders.contains("h264"), capabilities.encoders.contains("libx264") else { fatalError("Capability inspection failed") }
            print("Engine: \(capabilities.decoders.count) decoders, \(capabilities.encoders.count) encoders")
            for format in OutputFormat.allCases where format.isSupported(by: capabilities.encoders) {
                let output = folder.appendingPathComponent(UUID().uuidString).appendingPathExtension(format.fileExtension)
                try await ConversionEngine().convert(executable: executable, source: tiny, destination: output, format: format, size: .original, encoders: capabilities.encoders) { _ in }
                let streams = try command(probe, ["-v", "error", "-show_entries", "stream=codec_type", "-of", "csv=p=0", output.path])
                guard streams.contains("video") == !format.isAudioOnly, streams.contains("audio") else { fatalError("Missing streams for \(format)") }
                let expectedAudio: [OutputFormat: String] = [.alac: "alac", .opus: "opus", .wavpack: "wavpack", .aiff: "pcm_s16be", .ac3: "ac3"]
                let expectedVideo: [OutputFormat: String] = [.mjpeg: "mjpeg", .huffyuv: "huffyuv", .utvideo: "utvideo"]
                if let codec = expectedAudio[format] ?? expectedVideo[format] {
                    let stream = format.isAudioOnly ? "a:0" : "v:0"
                    let actual = try command(probe, ["-v", "error", "-select_streams", stream, "-show_entries", "stream=codec_name", "-of", "csv=p=0", output.path]).trimmingCharacters(in: .whitespacesAndNewlines)
                    assert(actual == codec, "Unexpected codec: \(actual)")
                }
                print("PASS \(format.rawValue) expected streams")
            }
        }
        for format in OutputFormat.allCases where format.isAudioOnly {
            let output = folder.appendingPathComponent("silent").appendingPathExtension(format.fileExtension)
            do {
                try await ConversionEngine().convert(executable: URL(fileURLWithPath: ffmpeg), source: avi, destination: output, format: format, size: .hd) { _ in }
                fatalError("Silent input should fail audio extraction")
            } catch {
                guard error.localizedDescription == "This file has no audio track to extract.",
                      !FileManager.default.fileExists(atPath: output.path) else { fatalError("Unexpected silent extraction result: \(error)") }
            }
        }
        print("PASS missing audio errors and cleanup")
        let qualityCapabilities = try await CodecCapabilities.inspect(URL(fileURLWithPath: ffmpeg))
        for format in OutputFormat.allCases where format.supportsVideoQuality && format.isSupported(by: qualityCapabilities.encoders) {
            for quality in [VideoQuality.smaller, .high] {
                let output = folder.appendingPathComponent(UUID().uuidString).appendingPathExtension(format.fileExtension)
                try await ConversionEngine().convert(executable: URL(fileURLWithPath: ffmpeg), source: tiny, destination: output, format: format, size: .original, quality: quality, encoders: qualityCapabilities.encoders) { _ in }
                let streams = try command(probe, ["-v", "error", "-show_entries", "stream=codec_type", "-of", "csv=p=0", output.path])
                assert(streams.contains("video") && streams.contains("audio"))
            }
        }
        let qualitySizes = try await qualityComparison(ffmpeg: ffmpeg, source: mpg, folder: folder)
        assert(qualitySizes.1 > qualitySizes.0, "Higher H.264 quality should retain more data for the test fixture")
        print("PASS all video quality presets and H.264 quality/file-size tradeoff")
        for format in [OutputFormat.mp4, .mov, .mkv, .hevc] {
            guard let encoder = format.hardwareEncoder, qualityCapabilities.encoders.contains(encoder) else { continue }
            for quality in VideoQuality.allCases {
                let args = format.arguments(quality: quality, hardwareAcceleration: true)
                assert(args.contains(encoder) && !args.contains("-crf") && !args.contains("-preset"))
                let output = folder.appendingPathComponent(UUID().uuidString).appendingPathExtension(format.fileExtension)
                try await ConversionEngine().convert(executable: URL(fileURLWithPath: ffmpeg), source: mpg, destination: output, format: format, size: .small, quality: quality, hardwareAcceleration: true, encoders: qualityCapabilities.encoders) { _ in }
                let codec = try command(probe, ["-v", "error", "-select_streams", "v:0", "-show_entries", "stream=codec_name,width,height", "-of", "csv=p=0", output.path]).trimmingCharacters(in: .whitespacesAndNewlines)
                assert(codec == (format == .hevc ? "hevc,854,480" : "h264,854,480"))
            }
            print("PASS hardware encoding: \(format.rawValue), all quality levels")
        }
        do {
            try await ConversionEngine().convert(executable: URL(fileURLWithPath: ffmpeg), source: mpg, destination: folder.appendingPathComponent("unavailable.mp4"), format: .mp4, size: .original, hardwareAcceleration: true, encoders: ["libx264", "aac"]) { _ in }
            fatalError("Unavailable hardware encoder should fail")
        } catch is ConversionFailure { print("PASS unavailable hardware encoder") }
        let bad = folder.appendingPathComponent("broken.avi")
        try Data("not a movie".utf8).write(to: bad)
        let output = folder.appendingPathComponent("failed.mp4")
        do {
            try await ConversionEngine().convert(executable: URL(fileURLWithPath: ffmpeg), source: bad, destination: output, format: .mp4, size: .original) { _ in }
            fatalError("Invalid input should fail")
        } catch { guard !FileManager.default.fileExists(atPath: output.path) else { fatalError("Failed output left behind") } }
        print("PASS invalid input cleanup")
        let cancelled = ConversionEngine()
        cancelled.cancel()
        do {
            try await cancelled.convert(executable: URL(fileURLWithPath: ffmpeg), source: mpg, destination: output, format: .mp4, size: .original) { _ in }
            fatalError("Cancellation should throw")
        } catch is CancellationError { print("PASS cancellation") }
        let existing = folder.appendingPathComponent("existing.mp4")
        let sentinel = Data("keep me".utf8)
        try sentinel.write(to: existing)
        do {
            try await ConversionEngine().convert(executable: URL(fileURLWithPath: ffmpeg), source: avi, destination: existing, format: .mp4, size: .original) { _ in }
            fatalError("Existing output should not be overwritten")
        } catch { guard try Data(contentsOf: existing) == sentinel else { fatalError("Overwrote existing file") } }
        print("PASS existing file protection")
        let leftovers = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix(".") }
        guard leftovers.isEmpty else { fatalError("Temporary outputs left behind") }
    }
}
