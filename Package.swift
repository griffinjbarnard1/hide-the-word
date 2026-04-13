// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ScriptureMemory",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "ScriptureMemory",
            targets: ["ScriptureMemory"]
        ),
    ],
    targets: [
        .target(
            name: "ScriptureMemory",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "ScriptureMemoryTests",
            dependencies: ["ScriptureMemory"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
