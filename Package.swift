// swift-tools-version: 5.10
// Swift package for Stagehand. build.sh turns the compiled executable into a .app bundle.
import PackageDescription

let package = Package(
    name: "Stagehand",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Stagehand", path: "Sources/Stagehand")
    ]
)
