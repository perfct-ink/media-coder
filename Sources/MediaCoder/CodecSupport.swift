import Foundation
import CryptoKit

struct CodecCapabilities: Sendable {
    var version = ""
    var encoders: Set<String> = []
    var decoders: Set<String> = []

    static func inspect(_ executable: URL) async throws -> CodecCapabilities {
        try await Task.detached {
            let version = try run(executable, ["-version"]).components(separatedBy: .newlines).first ?? "FFmpeg"
            let encoders = parse(try run(executable, ["-hide_banner", "-encoders"]))
            let decoders = parse(try run(executable, ["-hide_banner", "-decoders"]))
            return CodecCapabilities(version: version, encoders: encoders, decoders: decoders)
        }.value
    }

    static func parse(_ output: String) -> Set<String> {
        Set(output.split(separator: "\n").compactMap { line in
            let parts = line.split(whereSeparator: { $0.isWhitespace })
            guard parts.count >= 2, parts[0].count == 6,
                  ["V", "A", "S"].contains(String(parts[0].prefix(1))), parts[1] != "=" else { return nil }
            return String(parts[1])
        })
    }

    private static func run(_ executable: URL, _ arguments: [String]) throws -> String {
        let process = Process()
        let output = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw ConversionFailure(message: "Unable to inspect this FFmpeg executable.") }
        return String(decoding: data, as: UTF8.self)
    }
}

final class PackDownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    let progress: @Sendable (Double) -> Void
    init(progress: @escaping @Sendable (Double) -> Void) { self.progress = progress }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 { progress(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)) }
    }
}

/// A versioned, per-user engine install; it never modifies Homebrew or the app bundle.
enum CodecPack {
    static let release = "b6.1.1"
    #if arch(arm64)
    static let architecture = "arm64"
    static let engineVersion = "6.0"
    static let checksum = "a90e3db6a3fd35f6074b013f948b1aa45b31c6375489d39e572bea3f18336584"
    static let downloadSize = "46 MB"
    #else
    static let architecture = "x64"
    static let engineVersion = "6.1.1"
    static let checksum = "ebdddc936f61e14049a2d4b549a412b8a40deeff6540e58a9f2a2da9e6b18894"
    static let downloadSize = "79 MB"
    #endif
    static var folder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MediaCoder/Engines/\(release)-\(architecture)", isDirectory: true)
    }
    static var executable: URL { folder.appendingPathComponent("ffmpeg") }
    static var installed: Bool { FileManager.default.isExecutableFile(atPath: executable.path) }
    static let source = URL(string: "https://github.com/eugeneware/ffmpeg-static/releases/tag/b6.1.1")!
    static var base: String { "https://github.com/eugeneware/ffmpeg-static/releases/download/\(release)/" }

    static func install(progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        if installed { return executable }
        let staging = folder.deletingLastPathComponent().appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: staging) }
        let delegate = PackDownloadDelegate(progress: progress)
        let (download, response) = try await URLSession.shared.download(from: URL(string: base + "ffmpeg-darwin-\(architecture)")!, delegate: delegate)
        defer { try? FileManager.default.removeItem(at: download) }
        try check(response)
        try Task.checkCancellation()
        // Validate against the pinned release digest before making downloaded code executable.
        try await Task.detached {
            let data = try Data(contentsOf: download, options: .mappedIfSafe)
            let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            guard digest == checksum else { throw ConversionFailure(message: "Codec pack checksum did not match. Nothing was installed; try again.") }
        }.value
        let binary = staging.appendingPathComponent("ffmpeg")
        try FileManager.default.copyItem(at: download, to: binary)
        for name in ["LICENSE", "README"] {
            let (data, response) = try await URLSession.shared.data(from: URL(string: base + "darwin-\(architecture).\(name)")!)
            try check(response)
            try data.write(to: staging.appendingPathComponent(name))
        }
        try Task.checkCancellation()
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binary.path)
        let capabilities = try await CodecCapabilities.inspect(binary)
        guard !capabilities.decoders.isEmpty, capabilities.encoders.contains("libx264") else {
            throw ConversionFailure(message: "The downloaded engine could not be validated. Your existing engine is unchanged.")
        }
        try Task.checkCancellation()
        // Versioned installation leaves existing/custom engines intact.
        if installed { return executable }
        try FileManager.default.moveItem(at: staging, to: folder)
        return executable
    }

    private static func check(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ConversionFailure(message: "The codec pack download failed. Check your connection and try again.")
        }
    }
}
