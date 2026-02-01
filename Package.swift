// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FloatingText",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "FloatingText",
            path: "Sources/FloatingText"
        )
    ]
)
