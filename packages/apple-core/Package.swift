// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SuperDictateCore",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .watchOS(.v10),
    ],
    products: [
        .library(
            name: "SuperDictateCore",
            targets: ["SuperDictateCore"]
        ),
    ],
    targets: [
        .target(
            name: "SuperDictateCore"
        ),
        .testTarget(
            name: "SuperDictateCoreTests",
            dependencies: ["SuperDictateCore"]
        ),
    ]
)
