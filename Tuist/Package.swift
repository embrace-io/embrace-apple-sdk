// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.


import PackageDescription

#if TUIST
    import ProjectDescription

    let packageSettings = PackageSettings(
        productTypes: [
            "GRDB": .framework,
            "KSCrash": .framework,
            "OpenTelemetrySdk": .framework,
            "OpenTelemetryApi": .framework
        ]
    )

#endif

let package = Package(
    name: "EmbraceIO",
    platforms: [
        .iOS(.v13), .tvOS(.v13), .macOS(.v13), .watchOS(.v6)
    ],
    dependencies: [
        .package(
            url: "https://github.com/embrace-io/KSCrash.git",
            exact: "2.0.0"
        ),
        .package(
            url: "https://github.com/open-telemetry/opentelemetry-swift",
            exact: "1.5.1"
        ),
        .package(
            url: "https://github.com/groue/GRDB.swift",
            exact: "6.29.1"
        ),
        .package(
            url: "https://github.com/realm/SwiftLint",
            exact: "0.53.0"
        ),
        .package(
            url: "https://github.com/apple/swift-docc-plugin",
            branch: "main"
        )
    ]
)
