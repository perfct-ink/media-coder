import SwiftUI

@main
struct MediaCoderApp: App {
    @StateObject private var model = ConverterModel()
    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .frame(minWidth: 1000, minHeight: 620)
        }
        .defaultSize(width: 1100, height: 740)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add Videos…") { model.chooseFiles() }
                    .keyboardShortcut("o")
            }
        }
        Settings {
            TabView {
                CodecSupportView(model: model)
                    .tabItem { Label("Codecs", systemImage: "puzzlepiece.extension") }
            }
        }
    }
}
