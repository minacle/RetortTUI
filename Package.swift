// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .defaultIsolation(MainActor.self),
    .strictMemorySafety(),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("ImmutableWeakCaptures"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
]

let package = Package(
    name: "RetortTUI",
    platforms: [
        .macOS(.v15),
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
            ],
            swiftSettings: swiftSettings,
        ),
        .executableTarget(
            name: "RetortTUISample",
            dependencies: ["RetortTUI"],
            swiftSettings: swiftSettings,
        ),
        .testTarget(
            name: "RetortTUITests",
            dependencies: [
                "RetortTUI",
                .product(
                    name: "SwiftTUI",
                    package: "swift-tui"
                ),
            ],
            swiftSettings: swiftSettings,
        ),
    ],
    swiftLanguageModes: [.v6],
)
