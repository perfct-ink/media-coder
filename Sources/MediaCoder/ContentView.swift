import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var model: ConverterModel
    @State private var isTargeted = false
    @State private var errorDetails: String?
    private let accent = Color(red: 0.25, green: 0.40, blue: 0.95)

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 12) {
                Image(systemName: "film.stack.fill")
                    .font(.system(size: 26)).foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(accent.gradient, in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Media Coder").font(.system(size: 25, weight: .semibold))
                    Text("Convert your videos or extract their audio.").foregroundStyle(.secondary)
                }
                Spacer()
                SettingsLink { Label("Settings", systemImage: "gearshape") }
                    .buttonStyle(.bordered)
                Text("LOCAL & PRIVATE").font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1).foregroundStyle(.secondary)
            }

            if model.ffmpegURL == nil { setupBanner }

            VStack(spacing: 10) {
                Image(systemName: "arrow.down.doc.fill").font(.system(size: 30)).foregroundStyle(accent)
                Text("Drop videos here").font(.system(size: 19, weight: .semibold))
                HStack(spacing: 4) {
                    Text("MPG, AVI, MOV, MP4, MKV, and more · or")
                    Button("browse files") { model.chooseFiles() }.buttonStyle(.link)
                }.font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 27)
            .background(accent.opacity(isTargeted ? 0.12 : 0.04), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(accent.opacity(isTargeted ? 0.8 : 0.3), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])))
            .dropDestination(for: URL.self) { urls, _ in
                model.add(urls)
                return !urls.isEmpty
            } isTargeted: { isTargeted = $0 }

            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    label("CONVERT TO")
                    Picker("Format", selection: $model.format) {
                        Section("Convert video") {
                            ForEach(model.availableFormats.filter { !$0.isAudioOnly }) { Text($0.rawValue).tag($0) }
                        }
                        Section("Extract audio") {
                            ForEach(model.availableFormats.filter { $0.isAudioOnly }) { Text($0.rawValue).tag($0) }
                        }
                    }.pickerStyle(.menu).labelsHidden().frame(width: 240)
                }
                VStack(alignment: .leading, spacing: 8) {
                    label("VIDEO SIZE")
                    Picker("Video size", selection: $model.size) {
                        ForEach(VideoSize.allCases) { Text($0.rawValue).tag($0) }
                    }.labelsHidden().frame(width: 210).disabled(model.format.isAudioOnly)
                    if model.size == .custom && !model.format.isAudioOnly {
                        HStack(spacing: 6) {
                            TextField("Width", text: $model.customWidth)
                                .accessibilityLabel("Custom width in pixels")
                            Text("×")
                            TextField("Height", text: $model.customHeight)
                                .accessibilityLabel("Custom height in pixels")
                            Text("px").foregroundStyle(.secondary)
                        }.textFieldStyle(.roundedBorder).frame(width: 240)
                        Text(model.hasValidSize ? "Fit within these bounds; rounded to even pixels." : "Enter whole numbers from 2 to 16384.")
                            .font(.system(size: 11)).foregroundStyle(model.hasValidSize ? Color.secondary : Color.red)
                    }
                    Text(model.format.isAudioOnly ? "Extracts the first audio track only." : "Preserves aspect ratio. Never upscales.").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }.disabled(model.isConverting)

            if !model.format.isAudioOnly {
                HStack(alignment: .center, spacing: 16) {
                    label("OUTPUT QUALITY")
                    if model.format.supportsVideoQuality {
                        Picker("Output quality", selection: $model.quality) {
                            ForEach(VideoQuality.allCases) { Text($0.rawValue).tag($0) }
                        }.labelsHidden().frame(width: 170)
                        Text(model.usesHardwareAcceleration ? "Target video bitrate: \(model.format.hardwareBitrate(quality: model.quality))bit/s" : model.quality.description).font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Lossless encoding · resizing can still change pixels.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }.disabled(model.isConverting)
            }

            if model.format.hardwareEncoder != nil {
                HStack(spacing: 12) {
                    Toggle("Hardware acceleration", isOn: $model.hardwareAcceleration)
                        .toggleStyle(.checkbox)
                        .disabled(model.isConverting || !model.canUseHardwareAcceleration)
                    Text(model.canUseHardwareAcceleration
                         ? (model.usesHardwareAcceleration ? "Apple VideoToolbox encoding" : "Software encoding")
                         : "Unavailable in the selected engine")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "folder").foregroundStyle(.secondary)
                Text(model.outputFolder?.path ?? "Save alongside original videos")
                    .font(.system(size: 12)).lineLimit(1).truncationMode(.middle)
                    .help(model.outputFolder?.path ?? "Output files are saved in the same folder as each original.")
                Spacer()
                if model.outputFolder != nil {
                    Button("Reset") { model.outputFolder = nil }.buttonStyle(.link)
                }
                Button("Choose folder…") { model.chooseOutputFolder() }
            }.disabled(model.isConverting)

            ScrollView {
                videoDetail.frame(maxWidth: .infinity)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
                .task(id: "\(model.selectedJobID?.uuidString ?? "")|\(model.ffmpegURL?.path ?? "")") {
                    await model.loadSourceSpecs()
                }

            HStack {
                Text(model.isConverting ? "Converting…" : "Original files are always kept.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
                if model.isConverting {
                    Button("Cancel") { model.cancel() }
                } else {
                    Button { model.start() } label: {
                        Label(model.selectedJob?.status == .done && model.waitingCount > 0 ? "Next video" : (model.format.isAudioOnly ? "Extract audio" : "Convert video"), systemImage: model.selectedJob?.status == .done ? "arrow.right" : "arrow.triangle.2.circlepath")
                            .padding(.horizontal, 12).padding(.vertical, 5)
                    }.buttonStyle(.borderedProminent)
                        .disabled(!model.hasValidSize || model.waitingCount == 0 || model.ffmpegURL == nil || model.isInspecting || model.capabilities == nil || model.availableFormats.isEmpty || model.isDownloadingPack)
                }
            }
        }
            .padding(28)
        }.background(Color(nsColor: .windowBackgroundColor)).tint(accent)
        .alert("Media Coder", isPresented: Binding(get: { model.notice != nil }, set: { if !$0 { model.notice = nil } })) {
            Button("OK") { model.notice = nil }
        } message: { Text(model.notice ?? "") }
        .sheet(isPresented: Binding(get: { errorDetails != nil }, set: { if !$0 { errorDetails = nil } })) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Conversion details").font(.title2.bold())
                ScrollView { Text(errorDetails ?? "").font(.system(.caption, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                HStack { Spacer(); Button("Done") { errorDetails = nil }.keyboardShortcut(.defaultAction) }
            }.padding(24).frame(width: 620, height: 360)
        }
    }

    private func label(_ text: String) -> some View {
        Text(text).font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundStyle(.secondary)
    }

    private var setupBanner: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("FFmpeg is needed to convert videos", systemImage: "wrench.and.screwdriver").fontWeight(.medium)
            Text("Download the codec engine once, then convert offline.").font(.system(size: 12))
            HStack {
                SettingsLink { Text("Download codecs…") }
                Spacer()
                Button("Choose executable…") { model.chooseFFmpeg() }
                Button("Check again") { model.discoverFFmpeg() }
            }.font(.system(size: 12))
        }.padding(14).background(Color.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                label("VIDEOS · \(model.jobs.count)")
                Spacer()
                Button { model.chooseFiles() } label: { Image(systemName: "plus") }.help("Add videos")
            }.padding(.horizontal, 16).padding(.top, 20)
            if model.jobs.isEmpty {
                Text("Add videos to your queue.").font(.caption).foregroundStyle(.secondary).padding(16)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(model.jobs) { job in
                                Button { model.selectedJobID = job.id } label: {
                                    HStack(spacing: 9) {
                                        Image(systemName: job.status == .done ? "checkmark.circle.fill" : "film")
                                            .foregroundStyle(job.status == .done ? Color.green : accent)
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(job.source.lastPathComponent).font(.system(size: 12, weight: .medium)).lineLimit(2).multilineTextAlignment(.leading)
                                            Text(job.status == .converting ? "Converting · \(Int(job.progress * 100))%" : job.status.label).font(.caption2).foregroundStyle(.secondary)
                                            if job.status == .converting { ProgressView(value: job.progress).progressViewStyle(.linear) }
                                        }
                                        Spacer(minLength: 0)
                                    }.padding(11).frame(maxWidth: .infinity, alignment: .leading)
                                        .background(model.selectedJobID == job.id ? accent.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: 9))
                                        .contentShape(Rectangle())
                                }.buttonStyle(.plain).id(job.id).help(job.source.path)
                            }
                        }.padding(.horizontal, 8)
                    }
                    .onChange(of: model.selectedJobID) { _, id in
                        if let id { withAnimation { proxy.scrollTo(id, anchor: .center) } }
                    }
                }
            }
            if model.jobs.contains(where: { $0.status == .done }) {
                Button("Clear completed") { model.clearFinished() }.buttonStyle(.link).disabled(model.isConverting).padding(16)
            }
        }.frame(width: 250).background(Color(nsColor: .underPageBackgroundColor))
        .dropDestination(for: URL.self) { urls, _ in model.add(urls); return !urls.isEmpty }
    }

    @ViewBuilder
    private func sourceSpecs(_ job: VideoJob) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            label("SOURCE SPECS · FIRST VIDEO & AUDIO TRACKS")
            if let specs = job.sourceSpecs, job.specsEngine == model.ffmpegURL {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    specRow("Resolution", specs.resolution)
                    specRow("Video", specs.video)
                    specRow("Frame rate", specs.frameRate)
                    specRow("Duration", specs.duration)
                    specRow("Bitrate", specs.bitrate)
                    specRow("Audio", specs.audio)
                    specRow("File size", specs.fileSize)
                }.font(.caption).textSelection(.enabled)
            } else if let error = job.specsError {
                Text(error).font(.caption).foregroundStyle(.secondary)
                Button("Retry reading specs") { Task { await model.loadSourceSpecs() } }
            } else if model.ffmpegURL == nil {
                Text("Choose or download an engine to read source specs.").font(.caption).foregroundStyle(.secondary)
            } else {
                ProgressView("Reading source specs…").controlSize(.small)
            }
        }.padding(12).frame(maxWidth: 560, alignment: .leading)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
    }

    private func specRow(_ title: String, _ value: String) -> some View {
        GridRow(alignment: .top) {
            Text(title).foregroundStyle(.secondary)
            Text(value).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var videoDetail: some View {
        if let job = model.selectedJob {
            VStack(spacing: 12) {
                Image(systemName: job.status == .done ? "checkmark.circle.fill" : "film")
                    .font(.system(size: 38)).foregroundStyle(job.status == .done ? Color.green : accent)
                Text(job.source.lastPathComponent).font(.title3.weight(.semibold)).multilineTextAlignment(.center).textSelection(.enabled)
                sourceSpecs(job)
                Text(job.status.label).foregroundStyle(.secondary)
                if job.status == .converting {
                    ProgressView(value: job.progress).progressViewStyle(.linear).frame(maxWidth: 350)
                    Text("\(Int(job.progress * 100))%").monospacedDigit().font(.caption)
                }
                if let output = job.output {
                    Text(output.lastPathComponent).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([output]) }
                    if model.waitingCount > 0 { Text("Ready for the next video when you are.").font(.caption).foregroundStyle(.secondary) }
                    else { Text("All videos complete.").font(.caption).foregroundStyle(.secondary) }
                }
                if case .failed(let message) = job.status {
                    HStack {
                        Button("Details") { errorDetails = message }
                        SettingsLink { Text("Codec settings") }
                        Button("Retry") { model.retry(job.id) }.disabled(model.isConverting)
                    }
                }
                if job.status == .cancelled { Button("Retry") { model.retry(job.id) }.disabled(model.isConverting) }
                if job.status == .waiting {
                    Text("Output: \(model.uniqueOutput(source: job.source, folder: model.outputFolder ?? job.source.deletingLastPathComponent(), format: model.format, size: model.size).lastPathComponent)")
                        .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }
                Button("Remove from queue") { model.remove(job.id) }.buttonStyle(.link).disabled(model.isConverting)
            }.padding(20)
        } else {
            VStack(spacing: 6) {
                Text("Your queue is empty").fontWeight(.medium)
                Text("Add a few videos to get started.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
