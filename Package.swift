// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SubScript",
    defaultLocalization: "en",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "SubScript", targets: ["SubScript"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/soniqo/speech-swift",
            from: "0.0.12"
        ),
        .package(
            url: "https://github.com/su3/FFmpegKitSPM.git",
            .branch("main")
        ),
    ],
    targets: [
        .executableTarget(
            name: "SubScript",
            dependencies: [
                .product(name: "Qwen3ASR", package: "speech-swift"),
                .product(name: "SpeechVAD", package: "speech-swift"),
                .product(name: "SpeechUI", package: "speech-swift"),
                .product(name: "MADLADTranslation", package: "speech-swift"),
                .product(name: "Qwen3Chat", package: "speech-swift"),
                .product(name: "FFmpegKitSPM", package: "FFmpegKitSPM"),
            ],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
