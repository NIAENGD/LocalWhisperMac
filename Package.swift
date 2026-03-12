// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Audionyx",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Audionyx", targets: ["Audionyx"])
    ],
    targets: [
        .executableTarget(
            name: "Audionyx",
            path: "Sources/LocalWhisperMac",
            resources: [.process("Resources")]
        )
    ]
)
