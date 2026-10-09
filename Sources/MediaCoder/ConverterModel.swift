import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct VideoJob: Identifiable {
    let id = UUID()
    let source: URL
    var status: Status = .waiting
    var progress = 0.0
    var output: URL?
    var sourceSpecs: SourceSpecs?
    var specsEngine: URL?
    var specsError: String?
    enum Status: Equatable {
        case waiting, converting, done, failed(String), cancelled
        var label: String {
            switch self {
            case .waiting: return "Ready"
            case .converting: return "Converting"
            case .done: return "Complete"
            case .failed: return "Failed"
            case .cancelled: return "Cancelled"
            }
        }
    }
}

@MainActor
final class ConverterModel: ObservableObject {
    @Published var jobs: [VideoJob] = []
    @Published var selectedJobID: UUID?
    var selectedJob: VideoJob? { jobs.first { $0.id == selectedJobID } }
    @Published var format: OutputFormat = .mp4
    @Published var size: VideoSize = .original
    @Published var quality: VideoQuality = .balanced
    @Published var hardwareAcceleration = false
    var canUseHardwareAcceleration: Bool {
        guard let encoder = format.hardwareEncoder else { return false }
        return capabilities?.encoders.contains(encoder) == true
    }
    var usesHardwareAcceleration: Bool { hardwareAcceleration && canUseHardwareAcceleration }
    @Published var customWidth = "1920"
    @Published var customHeight = "1080"
    var customDimensions: (Int, Int)? {
        guard let width = Int(customWidth.trimmingCharacters(in: .whitespaces)),
              let height = Int(customHeight.trimmingCharacters(in: .whitespaces)),
              (2...16384).contains(width), (2...16384).contains(height) else { return nil }
        return (width, height)
    }
    var hasValidSize: Bool { format.isAudioOnly || size != .custom || customDimensions != nil }
    @Published var outputFolder: URL?
    @Published var isConverting = false
    @Published var ffmpegURL: URL?
    @Published var notice: String?
    private var engine: ConversionEngine?
    private var stopRequested = false
    @Published var capabilities: CodecCapabilities?
    @Published var capabilityError: String?
    @Published var isInspecting = false
    @Published var isDownloadingPack = false
    @Published var packProgress = 0.0
    @Published var packError: String?
    private var inspectionTask: Task<Void, Never>?
    private var downloadTask: Task<Void, Never>?

    var availableFormats: [OutputFormat] {
        guard let capabilities else { return OutputFormat.allCases }
        return OutputFormat.allCases.filter { $0.isSupported(by: capabilities.encoders) }
    }

    func downloadPack() {
        guard !isDownloadingPack, !isConverting else { return }
        isDownloadingPack = true
        packProgress = 0
        packError = nil
        downloadTask = Task { [weak self] in
            guard let self else { return }
            defer { self.isDownloadingPack = false; self.downloadTask = nil }
            do {
                let url = try await CodecPack.install { [weak self] value in
                    Task { @MainActor in self?.packProgress = value }
                }
                self.useEngine(url)
            } catch is CancellationError {
                self.packError = "Download cancelled. Your existing engine is unchanged."
            } catch {
                if (error as NSError).code == NSURLErrorCancelled {
                    self.packError = "Download cancelled. Your existing engine is unchanged."
                } else { self.packError = error.localizedDescription }
            }
        }
    }

    func cancelPackDownload() { downloadTask?.cancel() }

    func useEngine(_ url: URL) {
        guard !isConverting else { return }
        UserDefaults.standard.set(url.path, forKey: "ffmpegPath")
        ffmpegURL = url
        inspectEngine()
    }

    private func inspectEngine() {
        inspectionTask?.cancel()
        capabilities = nil
        capabilityError = nil
        guard let executable = ffmpegURL else { isInspecting = false; return }
        isInspecting = true
        inspectionTask = Task { [weak self] in
            do {
                let result = try await CodecCapabilities.inspect(executable)
                guard !Task.isCancelled, let self else { return }
                self.capabilities = result
                self.isInspecting = false
                if !self.format.isSupported(by: result.encoders), let first = self.availableFormats.first {
                    self.format = first
                }
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.capabilityError = error.localizedDescription
                self.isInspecting = false
            }
        }
    }


    init() { discoverFFmpeg() }

    var waitingCount: Int { jobs.filter { $0.status == .waiting }.count }

    func discoverFFmpeg() {
        let saved = UserDefaults.standard.string(forKey: "ffmpegPath")
        let candidates: [String?] = [saved, Bundle.main.url(forResource: "ffmpeg", withExtension: nil)?.path,
                          "/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", CodecPack.executable.path, "/usr/bin/ffmpeg"]
        let previous = ffmpegURL
        ffmpegURL = candidates.compactMap { $0 }.first { FileManager.default.isExecutableFile(atPath: $0) }.map { URL(fileURLWithPath: $0) }
        if previous != ffmpegURL || (capabilities == nil && !isInspecting) { inspectEngine() }
    }

    func chooseFFmpeg() {
        let panel = NSOpenPanel()
        panel.title = "Choose the FFmpeg executable"
        panel.message = "Select an FFmpeg binary, usually in /opt/homebrew/bin or /usr/local/bin."
        panel.canChooseDirectories = false
        panel.showsHiddenFiles = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard FileManager.default.isExecutableFile(atPath: url.path) else {
            notice = "The selected file is not executable. Select the ffmpeg binary."
            return
        }
        useEngine(url)
    }

    func loadSourceSpecs() async {
        guard let job = selectedJob, let executable = ffmpegURL else { return }
        if job.sourceSpecs != nil && job.specsEngine == executable { return }
        guard let index = jobs.firstIndex(where: { $0.id == job.id }) else { return }
        jobs[index].sourceSpecs = nil
        jobs[index].specsError = nil
        do {
            let specs = try await SourceSpecs.inspect(executable: executable, source: job.source)
            guard !Task.isCancelled, ffmpegURL == executable,
                  let index = jobs.firstIndex(where: { $0.id == job.id }) else { return }
            jobs[index].sourceSpecs = specs
            jobs[index].specsEngine = executable
        } catch {
            guard !Task.isCancelled, ffmpegURL == executable,
                  let index = jobs.firstIndex(where: { $0.id == job.id }) else { return }
            jobs[index].specsError = error.localizedDescription
        }
    }

    func chooseFiles() {
        let panel = NSOpenPanel()
        panel.title = "Add videos"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        add(panel.urls)
    }

    func add(_ urls: [URL]) {
        var rejected = 0
        for url in urls {
            var directory: ObjCBool = false
            guard url.isFileURL,
                  FileManager.default.fileExists(atPath: url.path, isDirectory: &directory),
                  !directory.boolValue, FileManager.default.isReadableFile(atPath: url.path) else {
                rejected += 1; continue
            }
            let canonical = url.standardizedFileURL
            if !jobs.contains(where: { $0.source.standardizedFileURL == canonical }) {
                let job = VideoJob(source: canonical)
                jobs.append(job)
                if selectedJobID == nil { selectedJobID = job.id }
            }
        }
        if rejected > 0 { notice = "Skipped \(rejected) item(s). Drop readable video files, rather than folders." }
    }

    func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose output folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK else { return }
        outputFolder = panel.url
    }

    func remove(_ id: UUID) {
        guard !isConverting else { return }
        jobs.removeAll { $0.id == id }
        if selectedJobID == id { selectedJobID = jobs.first?.id }
    }
    func clearFinished() {
        guard !isConverting else { return }
        jobs.removeAll { $0.status == .done }
        if !jobs.contains(where: { $0.id == selectedJobID }) { selectedJobID = jobs.first?.id }
    }
    func retry(_ id: UUID) {
        guard !isConverting, let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[index].status = .waiting
        jobs[index].progress = 0
    }
    func cancel() { stopRequested = true; engine?.cancel() }

    func start() {
        guard !isConverting, !isDownloadingPack, !isInspecting, waitingCount > 0 else { return }
        discoverFFmpeg()
        guard let executable = ffmpegURL else { notice = "Install FFmpeg, then click Check again or choose its executable."; return }
        guard let capabilities, format.isSupported(by: capabilities.encoders) else {
            notice = "The selected engine cannot encode this format. Open Settings → Codecs to download or choose another engine."
            return
        }
        guard hasValidSize else {
            notice = "Enter a width and height between 2 and 16384 pixels."
            return
        }
        let selectedDimensions = customDimensions
        let selectedFormat = format
        let selectedSize = size
        let selectedQuality = quality
        let selectedHardwareAcceleration = usesHardwareAcceleration
        let selectedFolder = outputFolder
        let nextID = selectedJob?.status == .waiting ? selectedJobID : jobs.first { $0.status == .waiting }?.id
        guard let nextID else { return }
        let ids = [nextID]
        isConverting = true
        stopRequested = false
        Task { [self] in
            defer { isConverting = false; engine = nil }
            for id in ids {
                if stopRequested { break }
                guard let index = jobs.firstIndex(where: { $0.id == id }) else { continue }
                selectedJobID = id
                let source = jobs[index].source
                let folder = selectedFolder ?? source.deletingLastPathComponent()
                let destination = uniqueOutput(source: source, folder: folder, format: selectedFormat, size: selectedSize)
                jobs[index].status = .converting
                let runner = ConversionEngine()
                engine = runner
                do {
                    try await runner.convert(executable: executable, source: source, destination: destination,
                                             format: selectedFormat, size: selectedSize, customDimensions: selectedDimensions, quality: selectedQuality, hardwareAcceleration: selectedHardwareAcceleration, encoders: capabilities.encoders) { [weak self] progress in
                        Task { @MainActor in
                            guard let self, let index = self.jobs.firstIndex(where: { $0.id == id }), self.jobs[index].status == .converting else { return }
                            self.jobs[index].progress = progress
                        }
                    }
                    jobs[index].status = .done
                    jobs[index].progress = 1
                    jobs[index].output = destination
                } catch is CancellationError {
                    jobs[index].status = .cancelled
                } catch {
                    jobs[index].status = .failed(error.localizedDescription)
                }
            }
        }
    }

    func uniqueOutput(source: URL, folder: URL, format: OutputFormat, size: VideoSize) -> URL {
        let suffix = size == .custom ? customDimensions.map { "\($0.0)x\($0.1)" } ?? "custom" : size.filenameSuffix
        let stem = source.deletingPathExtension().lastPathComponent + (format.isAudioOnly ? "-audio" : "-converted-" + suffix)
        var candidate = folder.appendingPathComponent(stem).appendingPathExtension(format.fileExtension)
        var number = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(stem)-\(number)").appendingPathExtension(format.fileExtension)
            number += 1
        }
        return candidate
    }
}
