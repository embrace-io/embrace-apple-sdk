// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "embrace-ios-core",
    products: [
        .library(
            name: "EmbraceIO",
            targets: ["embrace-ios-core"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/embrace-io/KSCrash.git",
            revision: "76e29fc61bc1446eb80720682ce88c617e95f65e" ),
        .package(
            url: "https://github.com/open-telemetry/opentelemetry-swift",
            from: "1.5.0" ),
        .package(
            url: "https://github.com/groue/GRDB.swift",
            from: "6.16.0"
        )
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "embrace-ios-core", dependencies: [
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
                .product(name: "GRDB", package: "GRDB.swift")
            ]),
        .testTarget(
            name: "embrace-ios-coreTests",
            dependencies: ["embrace-ios-core"])
    ]
)
