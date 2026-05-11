// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GameTranslator",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "GameTranslatorCore",
            targets: ["GameTranslatorCore"]
        ),
        .executable(
            name: "game-translator",
            targets: ["GameTranslatorApp"]
        )
    ],
    targets: [
        .target(
            name: "GameTranslatorCore"
        ),
        .executableTarget(
            name: "GameTranslatorApp",
            dependencies: ["GameTranslatorCore"]
        ),
        .testTarget(
            name: "GameTranslatorCoreTests",
            dependencies: ["GameTranslatorCore"]
        )
    ]
)
