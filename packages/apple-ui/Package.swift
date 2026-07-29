// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SuperDictateAppleUI",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "SuperDictateAppleUI",
            targets: ["SuperDictateAppleUI"]
        ),
    ],
    dependencies: [
        .package(path: "../apple-core"),
    ],
    targets: [
        .target(
            name: "SuperDictateAppleUI",
            dependencies: [
                .product(name: "SuperDictateCore", package: "apple-core"),
            ]
        ),
    ]
)
