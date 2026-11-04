// swift-tools-version: 6.0
// MDViewCore: everything that knows about Markdown (parsing, HTML,
// highlighting). No AppKit or WebKit. See docs/architecture.md.

import PackageDescription

let package = Package(
    name: "MDViewCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "MDViewCore", targets: ["MDViewCore"]),
    ],
    dependencies: [
        // The only allowed package (ADR 0001). Pinned to an exact version.
        .package(url: "https://github.com/swiftlang/swift-markdown.git", exact: "0.9.0"),
    ],
    targets: [
        .target(
            name: "MDViewCore",
            dependencies: [.product(name: "Markdown", package: "swift-markdown")]
        ),
        .testTarget(
            name: "MDViewCoreTests",
            dependencies: ["MDViewCore"]
        ),
    ]
)
