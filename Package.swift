// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LocalWhisperMac",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "LocalWhisperMac", targets: ["LocalWhisperMac"])
    ],
    targets: [
        .executableTarget(
            name: "LocalWhisperMac",
            resources: [.process("Resources")]
        )
    ]
)
