// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EmbraceIO",
    platforms: [
        .iOS(.v12), .tvOS(.v12), .macOS(.v12)
    ],
    products: [
        .library(
            name: "EmbraceIO",
            targets: ["EmbraceIO"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/embrace-io/KSCrash.git",
            revision: "76e29fc61bc1446eb80720682ce88c617e95f65e" ),
        .package(
            url: "https://github.com/open-telemetry/opentelemetry-swift",
            exact: "1.5.1" ),
        .package(
            url: "https://github.com/groue/GRDB.swift",
            exact: "6.16.0"
        ),
        .package(
            url: "https://github.com/realm/SwiftLint",
            exact: "0.52.4"
        ),
        .package(url: "https://github.com/apple/swift-docc-plugin",
                 branch: "main"
        )
    ],
    targets: [

        // core ----------------------------------------------------------------------
        .target(
            name: "EmbraceIO",
            dependencies: ["EmbraceOTel"],
            plugins: [
                .plugin(name: "SwiftLintPlugin", package: "SwiftLint")
            ]
        ),

        .testTarget(
            name: "EmbraceIOTests",
            dependencies: ["EmbraceIO"],
            plugins: [
                .plugin(name: "SwiftLintPlugin", package: "SwiftLint")
            ]
        ),

        // OTel ----------------------------------------------------------------------
        .target(
            name: "EmbraceOTel",
            dependencies: [
                "EmbraceStorage",
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift")
            ],
            plugins: [
                .plugin(name: "SwiftLintPlugin", package: "SwiftLint")
            ]
        ),
        .testTarget(
            name: "EmbraceOTelTests",
            dependencies: ["EmbraceOTel", "TestSupport"],
            plugins: [
                .plugin(name: "SwiftLintPlugin", package: "SwiftLint")
            ]
        ),

        // storage ----------------------------------------------------------------------
        .target(
            name: "EmbraceStorage",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift")
            ],
            plugins: [
                .plugin(name: "SwiftLintPlugin", package: "SwiftLint")
            ]
        ),
        .testTarget(
            name: "EmbraceStorageTests",
            dependencies: ["EmbraceStorage", "TestSupport"],
            plugins: [
                .plugin(name: "SwiftLintPlugin", package: "SwiftLint")
            ]
        ),

        // test support ----------------------------------------------------------------------
        .target(
            name: "TestSupport",
            dependencies: [.product(name: "OpenTelemetrySdk", package: "opentelemetry-swift") ],
            path: "Tests/TestSupport",
            plugins: [
                .plugin(name: "SwiftLintPlugin", package: "SwiftLint")
            ]
        )

    ]
)
