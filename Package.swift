// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "tracklaude",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "TracklaudeCore", targets: ["TracklaudeCore"]),
        .executable(name: "tracklaude", targets: ["tracklaude"]),
    ],
    targets: [
        // Pure logic. Must never import AppKit or SwiftUI.
        .target(name: "TracklaudeCore"),
        // SwiftUI menu-bar UI, app lifecycle, real I/O adapters.
        .executableTarget(
            name: "tracklaude",
            dependencies: ["TracklaudeCore"]
        ),
        // Swift Testing. With Command Line Tools only, run via `make test` (see Makefile).
        .testTarget(
            name: "TracklaudeCoreTests",
            dependencies: ["TracklaudeCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
