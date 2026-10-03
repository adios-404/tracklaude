// swift-tools-version: 6.0
import PackageDescription

// Renders the README's pictures of the app from the app's own views (see README.md here).
// A separate package so the app's build, tests and CI never see it.
let package = Package(
    name: "readme-art",
    platforms: [.macOS(.v14)],
    dependencies: [.package(name: "tracklaude", path: "../..")],
    targets: [
        .executableTarget(
            name: "ReadmeArt",
            dependencies: [.product(name: "TracklaudeCore", package: "tracklaude")]
        ),
    ]
)
