// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "MediaCoder",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "MediaCoder", targets: ["MediaCoder"])],
    targets: [.executableTarget(name: "MediaCoder")],
    swiftLanguageModes: [.v5]
)
