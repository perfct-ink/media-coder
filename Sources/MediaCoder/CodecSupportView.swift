import SwiftUI
import AppKit

struct CodecSupportView: View {
    @ObservedObject var model: ConverterModel
    @State private var search = ""
    @State private var showEncoders = false

    private var names: [String] {
        let values = showEncoders ? model.capabilities?.encoders : model.capabilities?.decoders
        return (values ?? []).filter { search.isEmpty || $0.localizedCaseInsensitiveContains(search) }.sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                FilmIconArtwork(size: 40)
                Text("Codec support").font(.title2.bold())
            }
            Text("Most codecs are built into the video engine. Download it once, or use your own FFmpeg build for additional codecs.")
                .font(.callout).foregroundStyle(.secondary)
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Active engine", systemImage: "cpu")
                        Spacer()
                        if model.isInspecting { ProgressView().controlSize(.small) }
                        Button("Choose engine…") { model.chooseFFmpeg() }
                            .disabled(model.isConverting || model.isDownloadingPack)
                    }
                    Text(model.capabilities?.version ?? (model.ffmpegURL == nil ? "No engine installed" : "Checking engine…"))
                        .font(.caption).textSelection(.enabled)
                    if let url = model.ffmpegURL {
                        Text(url.path).font(.caption2).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                    if let error = model.capabilityError { Text(error).font(.caption).foregroundStyle(.red) }
                    if let capabilities = model.capabilities {
                        Text("\(capabilities.decoders.count) decoders · \(capabilities.encoders.count) encoders · \(model.availableFormats.count) output presets")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
            }
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Portable codec pack", systemImage: "arrow.down.circle")
                        Spacer()
                        Text("FFmpeg \(CodecPack.engineVersion) · \(CodecPack.downloadSize)").font(.caption).foregroundStyle(.secondary)
                    }
                    Text("Includes support for many modern and legacy codecs. Installs in your user folder, without Homebrew. It may offer different codecs from your current engine.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    if model.isDownloadingPack {
                        ProgressView(value: model.packProgress)
                        HStack {
                            Text(model.packProgress >= 1 ? "Verifying and installing…" : "Downloading · \(Int(model.packProgress * 100))%")
                                .font(.caption).monospacedDigit()
                            Spacer()
                            Button("Cancel download") { model.cancelPackDownload() }
                        }
                    } else {
                        HStack {
                            Link("Source & license", destination: CodecPack.source)
                            Spacer()
                            if CodecPack.installed {
                                Button("Use downloaded pack") { model.useEngine(CodecPack.executable) }
                                    .disabled(model.isConverting || model.ffmpegURL == CodecPack.executable)
                            } else {
                                Button("Download codec pack") { model.downloadPack() }
                                    .buttonStyle(.borderedProminent).disabled(model.isConverting)
                            }
                        }.font(.caption)
                    }
                    if let error = model.packError { Text(error).font(.caption).foregroundStyle(.red) }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
            }
            HStack {
                Picker("Codec list", selection: $showEncoders) {
                    Text("Read / decode").tag(false)
                    Text("Write / encode").tag(true)
                }.pickerStyle(.segmented).labelsHidden().frame(width: 260)
                TextField("Search codecs", text: $search).textFieldStyle(.roundedBorder)
            }
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 7) {
                    ForEach(names, id: \.self) { Text($0).font(.system(.caption, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                }.padding(8)
                if names.isEmpty { Text("No matching codecs").foregroundStyle(.secondary).padding() }
            }.background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            HStack {
                Text("Videos stay on your Mac. Only the engine is downloaded.").font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
        }.padding(24).frame(width: 690, height: 680)
    }
}
