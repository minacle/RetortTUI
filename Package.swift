// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RetortTUI",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "RetortTUI",
            targets: ["RetortTUI"]
        ),
        .executable(
            name: "RetortTUISample",
            targets: ["RetortTUISample"]
        ),
    ],
    dependencies: [
        .package(
            path: "../swift-tui"
        ),
    ],
    targets: [
        .target(
            name: "RetortTUI",
            dependencies: [
                .product(
                    name: "SwiftTUI",
                    package: "swift-tui"
                ),
            ]
        ),
        .executableTarget(
            name: "RetortTUISample",
            dependencies: ["RetortTUI"]
        ),
        .testTarget(
            name: "RetortTUITests",
            dependencies: [
                "RetortTUI",
                .product(
                    name: "SwiftTUI",
                    package: "swift-tui"
                ),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
