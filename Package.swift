// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RetortTUI",
    platforms: [
        .macOS(.v11),
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
            url: "https://github.com/apple/swift-system",
            from: "1.7.2"
        ),
        .package(
            url: "https://github.com/minacle/swift-terminal",
            branch: "main"
        ),
        .package(
            url: "https://github.com/minacle/swift-termios",
            branch: "main"
        ),
        .package(
            url: "https://github.com/OpenSwiftUIProject/OpenCombine.git",
            from: "0.15.0"
        ),
    ],
    targets: [
        .target(
            name: "RetortTUI",
            dependencies: [
                .product(
                    name: "SystemPackage",
                    package: "swift-system"
                ),
                .product(
                    name: "Terminal",
                    package: "swift-terminal"
                ),
                .product(
                    name: "Termios",
                    package: "swift-termios"
                ),
                .product(
                    name: "OpenCombine",
                    package: "OpenCombine",
                    condition: .when(platforms: [.linux])
                ),
            ]
        ),
        .executableTarget(
            name: "RetortTUISample",
            dependencies: ["RetortTUI"]
        ),
        .testTarget(
            name: "RetortTUITests",
            dependencies: ["RetortTUI"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
