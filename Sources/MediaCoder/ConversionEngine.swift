import Foundation

enum VideoQuality: String, CaseIterable, Identifiable {
    case smaller = "Smaller file", balanced = "Balanced", high = "High quality"
    var id: String { rawValue }
    var description: String {
        switch self {
        case .smaller: return "More compression, smaller files."
        case .balanced: return "A balance of detail and file size."
        case .high: return "Less compression, larger files."
        }
    }
    func value(_ smaller: String, _ balanced: String, _ high: String) -> String {
        switch self {
        case .smaller: return smaller
        case .balanced: return balanced
        case .high: return high
        }
    }
}

enum OutputFormat: String, CaseIterable, Identifiable {
    case mp4 = "MP4 · H.264", hevc = "MP4 · HEVC / H.265", av1 = "MP4 · AV1"
    case mov = "MOV · H.264", prores = "MOV · ProRes"
    case webm = "WebM · VP9", vp8 = "WebM · VP8"
    case mkv = "MKV · H.264", lossless = "MKV · FFV1 lossless"
    case avi = "AVI · MPEG-4", mpg = "MPG · MPEG-2", wmv = "WMV · Windows Media"
    case m4a = "M4A · AAC", mp3 = "MP3", wav = "WAV · PCM", flac = "FLAC · Lossless"
    case mjpeg = "MOV · Motion JPEG", huffyuv = "AVI · HuffYUV lossless", utvideo = "AVI · Ut Video lossless"
    case alac = "M4A · Apple Lossless", opus = "Opus", wavpack = "WavPack · Lossless"
    case aiff = "AIFF · PCM", ac3 = "AC-3 · Dolby Digital"
    var isAudioOnly: Bool { [.m4a, .mp3, .wav, .flac, .alac, .opus, .wavpack, .aiff, .ac3].contains(self) }
    var supportsVideoQuality: Bool { !isAudioOnly && ![.lossless, .huffyuv, .utvideo].contains(self) }
    var id: String { rawValue }
    var fileExtension: String {
        switch self {
        case .mp4, .hevc, .av1: return "mp4"
        case .mov, .prores, .mjpeg: return "mov"
        case .webm, .vp8: return "webm"
        case .mkv, .lossless: return "mkv"
        case .avi, .huffyuv, .utvideo: return "avi"
        case .mpg: return "mpg"
        case .wmv: return "wmv"
        case .m4a, .alac: return "m4a"
        case .mp3: return "mp3"
        case .wav: return "wav"
        case .flac: return "flac"
        case .opus: return "opus"
        case .wavpack: return "wv"
        case .aiff: return "aiff"
        case .ac3: return "ac3"
        }
    }
    var videoEncoder: String {
        switch self {
        case .mp4, .mov, .mkv: return "libx264"
        case .hevc: return "libx265"
        case .av1: return "libaom-av1"
        case .prores: return "prores_ks"
        case .webm: return "libvpx-vp9"
        case .vp8: return "libvpx"
        case .lossless: return "ffv1"
        case .avi: return "mpeg4"
        case .mpg: return "mpeg2video"
        case .wmv: return "wmv2"
        case .mjpeg: return "mjpeg"
        case .huffyuv: return "huffyuv"
        case .utvideo: return "utvideo"
        case .m4a, .mp3, .wav, .flac, .alac, .opus, .wavpack, .aiff, .ac3: return ""
        }
    }
    var audioEncoder: String {
        switch self {
        case .prores, .wav, .mjpeg, .huffyuv, .utvideo: return "pcm_s16le"
        case .webm, .vp8, .opus: return "libopus"
        case .lossless, .flac: return "flac"
        case .avi, .mp3: return "libmp3lame"
        case .mpg: return "mp2"
        case .wmv: return "wmav2"
        case .alac: return "alac"
        case .wavpack: return "wavpack"
        case .aiff: return "pcm_s16be"
        case .ac3: return "ac3"
        default: return "aac"
        }
    }
    var hardwareEncoder: String? {
        switch self {
        case .mp4, .mov, .mkv: return "h264_videotoolbox"
        case .hevc: return "hevc_videotoolbox"
        default: return nil
        }
    }
    func hardwareBitrate(quality: VideoQuality) -> String {
        quality.value("4M", "8M", "16M")
    }
    var videoEncoderOptions: [String] { self == .av1 ? ["libaom-av1", "libsvtav1"] : [videoEncoder] }
    func isSupported(by encoders: Set<String>) -> Bool {
        (isAudioOnly || videoEncoderOptions.contains(where: encoders.contains)) && encoders.contains(audioEncoder)
    }
    func arguments(encoders: Set<String>? = nil, quality: VideoQuality = .balanced, hardwareAcceleration: Bool = false) -> [String] {
        if hardwareAcceleration, let hardwareEncoder {
            return ["-c:v", hardwareEncoder, "-allow_sw", "0", "-b:v", hardwareBitrate(quality: quality),
                    "-pix_fmt", "yuv420p", "-c:a", audioEncoder, "-b:a", "192k"]
                + (self == .hevc ? ["-tag:v", "hvc1"] : [])
                + (self == .mkv ? [] : ["-movflags", "+faststart"])
        }
        let selected = videoEncoderOptions.first { encoders?.contains($0) ?? true } ?? videoEncoder
        let codecs = ["-c:v", selected, "-c:a", audioEncoder]
        switch self {
        case .mp4, .mov, .mkv:
            return codecs + ["-preset", "medium", "-crf", quality.value("28", "22", "18"), "-pix_fmt", "yuv420p", "-b:a", "192k"] + (self == .mkv ? [] : ["-movflags", "+faststart"])
        case .hevc:
            return codecs + ["-preset", "medium", "-crf", quality.value("32", "26", "20"), "-pix_fmt", "yuv420p", "-tag:v", "hvc1", "-b:a", "192k", "-movflags", "+faststart"]
        case .av1:
            return codecs + ["-crf", quality.value("40", "32", "24"), "-b:v", "0"] + (selected == "libsvtav1" ? ["-preset", "8"] : ["-cpu-used", "6"]) + ["-pix_fmt", "yuv420p", "-b:a", "192k", "-movflags", "+faststart"]
        case .prores:
            return codecs + ["-profile:v", quality.value("1", "2", "3"), "-pix_fmt", "yuv422p10le"]
        case .webm, .vp8:
            return codecs + ["-crf", quality.value("40", "32", "24"), "-b:v", quality.value("600k", "1M", "3M"), "-pix_fmt", "yuv420p", "-b:a", "128k"]
        case .lossless:
            return codecs + ["-level", "3"]
        case .avi:
            return codecs + ["-q:v", quality.value("7", "3", "2"), "-pix_fmt", "yuv420p", "-b:a", "192k"]
        case .mpg:
            return codecs + ["-q:v", quality.value("7", "3", "2"), "-pix_fmt", "yuv420p", "-r", "25", "-b:a", "192k", "-ar", "48000"]
        case .m4a:
            return ["-c:a", audioEncoder, "-b:a", "192k", "-movflags", "+faststart"]
        case .mp3:
            return ["-c:a", audioEncoder, "-q:a", "2"]
        case .wav, .flac, .alac, .wavpack, .aiff:
            return ["-c:a", audioEncoder]
        case .opus:
            return ["-c:a", audioEncoder, "-b:a", "160k", "-ar", "48000"]
        case .ac3:
            return ["-c:a", audioEncoder, "-b:a", "384k", "-ar", "48000", "-ac", "2"]
        case .mjpeg:
            return codecs + ["-q:v", quality.value("7", "3", "2"), "-pix_fmt", "yuvj422p"]
        case .huffyuv:
            return codecs + ["-pix_fmt", "yuv422p"]
        case .utvideo:
            return codecs + ["-pix_fmt", "yuv422p"]
        case .wmv:
            return codecs + ["-b:v", quality.value("1M", "3M", "6M"), "-pix_fmt", "yuv420p", "-b:a", "128k"]
        }
    }
}

enum VideoSize: String, CaseIterable, Identifiable {
    case original = "Original size", fullHD = "1080p", hd = "720p", small = "480p"
    case twoK = "2K · 2560×1440", fourK = "4K · 3840×2160", custom = "Custom"
    var id: String { rawValue }
    var filenameSuffix: String {
        switch self {
        case .original: return "original"
        case .twoK: return "2k"
        case .fourK: return "4k"
        default: return rawValue.lowercased()
        }
    }
    var dimensions: (Int, Int)? {
        switch self {
        case .original, .custom: return nil
        case .twoK: return (2560, 1440)
        case .fourK: return (3840, 2160)
        case .fullHD: return (1920, 1080)
        case .hd: return (1280, 720)
        case .small: return (854, 480)
        }
    }
    func filter(customDimensions: (Int, Int)? = nil) throws -> String {
        if self == .custom {
            guard let (width, height) = customDimensions,
                  (2...16384).contains(width), (2...16384).contains(height) else {
                throw ConversionFailure(message: "Enter a width and height between 2 and 16384 pixels.")
            }
        }
        let normalize = "scale=w='max(2,trunc(iw*sar/2)*2)':h='max(2,trunc(ih/2)*2)',setsar=1"
        if let (width, height) = self == .custom ? customDimensions : dimensions {
            return normalize + ",scale=w='min(iw,\(width))':h='min(ih,\(height))':force_original_aspect_ratio=decrease:force_divisible_by=2,setsar=1"
        }
        return normalize
    }
}

struct ConversionFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Each conversion runs off the UI thread; the lock only protects cancellation.
final class ConversionEngine: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false

    func cancel() {
        lock.lock()
        cancelled = true
        let running = process
        lock.unlock()
        if let running, running.isRunning { running.terminate() }
    }

    func convert(executable: URL, source: URL, destination: URL, format: OutputFormat,
                 size: VideoSize, customDimensions: (Int, Int)? = nil, quality: VideoQuality = .balanced, hardwareAcceleration: Bool = false, encoders: Set<String>? = nil, progress: @escaping @Sendable (Double) -> Void) async throws {
        if hardwareAcceleration {
            guard let encoder = format.hardwareEncoder, encoders?.contains(encoder) ?? true else {
                throw ConversionFailure(message: "Hardware encoding is unavailable for this format or engine. Turn off hardware acceleration and retry.")
            }
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                // Write to a unique temporary file so failed jobs never leave a misleading final video.
                let temporary = destination.deletingLastPathComponent()
                    .appendingPathComponent(".\(UUID().uuidString).\(format.fileExtension)")
                defer { try? FileManager.default.removeItem(at: temporary) }
                let errorLog = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                FileManager.default.createFile(atPath: errorLog.path, contents: nil)
                defer { try? FileManager.default.removeItem(at: errorLog) }
                do {
                    let errors = try FileHandle(forWritingTo: errorLog)
                    defer { try? errors.close() }
                    let pipe = Pipe()
                    let job = Process()
                    job.executableURL = executable
                    let streams = format.isAudioOnly
                        ? ["-map", "0:a:0", "-vn", "-sn", "-dn"]
                        : ["-map", "0:v:0", "-map", "0:a:0?", "-vf", try size.filter(customDimensions: customDimensions)]
                    job.arguments = ["-hide_banner", "-nostdin", "-n", "-i", source.path] + streams
                        + format.arguments(encoders: encoders, quality: quality, hardwareAcceleration: hardwareAcceleration) + ["-progress", "pipe:1", "-nostats", temporary.path]
                    job.standardOutput = pipe
                    job.standardError = errors
                    lock.lock()
                    if cancelled {
                        lock.unlock()
                        throw CancellationError()
                    }
                    process = job
                    // Launch while holding the lock so cancellation cannot miss the running process.
                    do { try job.run() } catch { lock.unlock(); throw error }
                    lock.unlock()
                    var pending = ""
                    var duration: Double?
                    while true {
                        let data = pipe.fileHandleForReading.availableData
                        if data.isEmpty { break }
                        pending += String(decoding: data, as: UTF8.self)
                        if duration == nil, let log = try? String(contentsOf: errorLog, encoding: .utf8) {
                            duration = Self.duration(in: log)
                        }
                        while let newline = pending.firstIndex(of: "\n") {
                            let line = String(pending[..<newline])
                            pending.removeSubrange(...newline)
                            if line.hasPrefix("out_time_us="),
                               let microseconds = Double(line.dropFirst(12)), let duration, duration > 0 {
                                progress(min(0.99, max(0, microseconds / 1_000_000 / duration)))
                            }
                        }
                    }
                    job.waitUntilExit()
                    lock.lock()
                    let wasCancelled = cancelled
                    process = nil
                    lock.unlock()
                    if wasCancelled { throw CancellationError() }
                    guard job.terminationStatus == 0 else {
                        let log = (try? String(contentsOf: errorLog, encoding: .utf8)) ?? ""
                        if format.isAudioOnly && log.contains("matches no streams") {
                            throw ConversionFailure(message: "This file has no audio track to extract.")
                        }
                        let hint = hardwareAcceleration ? "Hardware encoding failed. Turn off hardware acceleration and retry.\n\n" : ""
                        throw ConversionFailure(message: hint + String(log.suffix(2500)).trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                    try FileManager.default.moveItem(at: temporary, to: destination)
                    progress(1)
                    continuation.resume()
                } catch {
                    lock.lock(); process = nil; lock.unlock()
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func duration(in log: String) -> Double? {
        guard let range = log.range(of: "Duration: ") else { return nil }
        let value = log[range.upperBound...].prefix(11).split(separator: ":")
        guard value.count == 3, let hours = Double(value[0]), let minutes = Double(value[1]), let seconds = Double(value[2]) else { return nil }
        return hours * 3600 + minutes * 60 + seconds
    }
}

/// Uses the active FFmpeg engine so the portable pack does not need ffprobe.
struct SourceSpecs: Sendable {
    let duration: String
    let bitrate: String
    let video: String
    let resolution: String
    let frameRate: String
    let audio: String
    let fileSize: String

    static func inspect(executable: URL, source: URL) async throws -> SourceSpecs {
        try await Task.detached(priority: .utility) {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = executable
            process.arguments = ["-hide_banner", "-nostdin", "-i", source.path]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = pipe
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            // FFmpeg exits nonzero because inspection intentionally specifies no output.
            let log = String(decoding: data, as: UTF8.self)
            let bytes = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize
            return try parse(log, bytes: bytes)
        }.value
    }

    static func parse(_ log: String, bytes: Int?) throws -> SourceSpecs {
        let lines = log.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
        let streams = lines.filter { $0.hasPrefix("Stream #0:") }
        guard !streams.isEmpty else {
            throw ConversionFailure(message: "Could not read source specs. The file may be unsupported or damaged.")
        }
        func match(_ pattern: String, in text: String) -> String? {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let result = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let range = Range(result.range(at: 1), in: text) else { return nil }
            return String(text[range])
        }
        let videoLine = streams.first { $0.contains(": Video: ") } ?? ""
        let audioLine = streams.first { $0.contains(": Audio: ") } ?? ""
        let durationLine = lines.first { $0.hasPrefix("Duration:") } ?? ""
        let audio = audioLine.components(separatedBy: ": Audio: ").dropFirst().joined(separator: ": Audio: ")
        return SourceSpecs(
            duration: match("Duration: ([^,]+)", in: durationLine) ?? "Unknown",
            bitrate: match("bitrate: (.+)$", in: durationLine) ?? "Unknown",
            video: match(": Video: ([^,]+)", in: videoLine) ?? "No video track",
            resolution: match(", ([0-9]+x[0-9]+)(?:[ ,\\[])", in: videoLine)?.replacingOccurrences(of: "x", with: " × ") ?? "Unknown",
            frameRate: match("([0-9.]+) fps", in: videoLine).map { $0 + " fps" } ?? "Unknown",
            audio: audio.isEmpty ? "No audio track" : audio,
            fileSize: bytes.map { ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file) } ?? "Unknown")
    }
}
