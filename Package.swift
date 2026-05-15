// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "yLLMKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "yLLMKit",
            targets: ["yLLMKit"]
        )
    ],
    targets: [
        .target(
            name: "yLLMKit"
        ),
        .testTarget(
            name: "yLLMKitTests",
            dependencies: ["yLLMKit"]
        )
    ]
)
