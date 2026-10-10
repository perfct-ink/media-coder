import AppKit
import SwiftUI

@main
struct GenerateAppIcon {
    @MainActor static func main() throws {
        guard CommandLine.arguments.count == 2 else { fatalError("Pass the AppIcon.appiconset output directory") }
        let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var images: [[String: String]] = []
        for points in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let pixels = CGFloat(points * scale)
                let artwork = FilmIconDrawing(size: pixels * 0.80)
                    .frame(width: pixels, height: pixels)
                    .environment(\.colorScheme, .light)
                let renderer = ImageRenderer(content: artwork)
                renderer.scale = 1
                guard let image = renderer.cgImage,
                      let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
                    fatalError("Failed to render icon")
                }
                let name = "icon_\(points)x\(points)@\(scale)x.png"
                try png.write(to: folder.appendingPathComponent(name))
                if points == 512 && scale == 2 {
                    let logo = folder.deletingLastPathComponent().appendingPathComponent("AppLogo.imageset")
                    try FileManager.default.createDirectory(at: logo, withIntermediateDirectories: true)
                    try png.write(to: logo.appendingPathComponent("logo.png"))
                    let metadata: [String: Any] = ["images": [["idiom": "universal", "filename": "logo.png"]], "info": ["author": "xcode", "version": 1]]
                    try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
                        .write(to: logo.appendingPathComponent("Contents.json"))
                }
                images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": name])
            }
        }
        let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
        try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
            .write(to: folder.appendingPathComponent("Contents.json"))
    }
}
