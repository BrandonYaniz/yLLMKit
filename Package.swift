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
        ),
        .library(
            name: "yLLMKitMLX",
            targets: ["yLLMKitMLX"]
        ),
        .library(
            name: "yLLMKitOpenAI",
            targets: ["yLLMKitOpenAI"]
        ),
        .library(
            name: "yLLMKitAnthropic",
            targets: ["yLLMKitAnthropic"]
        ),
        .library(
            name: "yLLMKitContext",
            targets: ["yLLMKitContext"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", .upToNextMajor(from: "7.10.0")),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", .upToNextMajor(from: "3.31.3")),
        .package(url: "https://github.com/huggingface/swift-huggingface", from: "0.9.0"),
        .package(url: "https://github.com/huggingface/swift-transformers", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "yLLMKit"
        ),
        .target(
            name: "yLLMKitMLX",
            dependencies: [
                "yLLMKit",
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "MLXHuggingFace", package: "mlx-swift-lm"),
                .product(name: "HuggingFace", package: "swift-huggingface"),
                .product(name: "Tokenizers", package: "swift-transformers")
            ]
        ),
        .target(
            name: "yLLMKitOpenAI",
            dependencies: ["yLLMKit"]
        ),
        .target(
            name: "yLLMKitAnthropic",
            dependencies: ["yLLMKit"]
        ),
        .target(
            name: "yLLMKitContext",
            dependencies: [
                "yLLMKit",
                .product(name: "GRDB", package: "GRDB.swift")
            ]
        ),
        .testTarget(
            name: "yLLMKitTests",
            dependencies: ["yLLMKit"]
        ),
        .testTarget(
            name: "yLLMKitMLXTests",
            dependencies: [
                "yLLMKit",
                "yLLMKitMLX"
            ]
        ),
        .testTarget(
            name: "yLLMKitOpenAITests",
            dependencies: [
                "yLLMKit",
                "yLLMKitOpenAI"
            ]
        ),
        .testTarget(
            name: "yLLMKitAnthropicTests",
            dependencies: [
                "yLLMKit",
                "yLLMKitAnthropic"
            ]
        ),
        .testTarget(
            name: "yLLMKitContextTests",
            dependencies: [
                "yLLMKit",
                "yLLMKitContext"
            ]
        )
    ]
)
