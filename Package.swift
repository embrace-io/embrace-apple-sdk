// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

var targetPlugins: [Target.PluginUsage] = [.plugin(name: "SwiftLintPlugin", package: "SwiftLint")]
// Work around for plugin dependency being included in iOS target when using `xcodebuild test`
// (See bin/xctest)
// https://forums.swift.org/t/xcode-attempts-to-build-plugins-for-ios-is-there-a-workaround/57029
if ProcessInfo.processInfo.environment["IS_XCTEST"] != nil {
    targetPlugins.removeAll()
}

let package = Package(
    name: "EmbraceIO",
    platforms: [
        .iOS(.v13), .tvOS(.v13), .macOS(.v13)
    ],
    products: [
        .library(name: "EmbraceIO", targets: ["EmbraceIO"]),
        .library(name: "EmbraceCrash", targets: ["EmbraceCrash"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/embrace-io/KSCrash.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/open-telemetry/opentelemetry-swift",
            exact: "1.5.1"
        ),
        .package(
            url: "https://github.com/groue/GRDB.swift",
            exact: "6.16.0"
        ),
        .package(
            url: "https://github.com/realm/SwiftLint",
            exact: "0.53.0"
        ),
        .package(
            url: "https://github.com/apple/swift-docc-plugin",
            branch: "main"
        ),
        .package(
            url: "https://github.com/1024jp/GzipSwift",
            exact: "6.0.1"
        )
    ],
    targets: [

        // core ----------------------------------------------------------------------
        .target(
            name: "EmbraceIO",
            dependencies: [
                "EmbraceOTel",
                "EmbraceStorage",
                "EmbraceUpload",
                "EmbraceObjCUtils",
                .product(name: "Gzip", package: "GzipSwift")
            ],
            plugins: targetPlugins
        ),

        .testTarget(
            name: "EmbraceIOTests",
            dependencies: [
                "EmbraceIO",
                "EmbraceCrash",
                "TestSupport",
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            resources: [
                .copy("Mocks/")
            ],
            plugins: targetPlugins
        ),

        .target(
            name: "EmbraceCommon",
            plugins: targetPlugins
        ),
        .testTarget(
            name: "EmbraceCommonTests",
            dependencies: ["EmbraceCommon", "TestSupport"],
            plugins: targetPlugins
        ),

        // OTel ----------------------------------------------------------------------
        .target(
            name: "EmbraceOTel",
            dependencies: [
                "EmbraceCommon",
                "EmbraceStorage",
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift")
            ],
            plugins: targetPlugins
        ),
        .testTarget(
            name: "EmbraceOTelTests",
            dependencies: ["EmbraceOTel", "TestSupport"],
            plugins: targetPlugins
        ),

        // storage ----------------------------------------------------------------------
        .target(
            name: "EmbraceStorage",
            dependencies: [
                "EmbraceCommon",
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift")
            ],
            plugins: targetPlugins
        ),
        .testTarget(
            name: "EmbraceStorageTests",
            dependencies: ["EmbraceStorage", "TestSupport"],
            plugins: targetPlugins
        ),

        // upload ----------------------------------------------------------------------
        .target(
            name: "EmbraceUpload",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            plugins: targetPlugins
        ),
        .testTarget(
            name: "EmbraceUploadTests",
            dependencies: ["EmbraceUpload", "TestSupport"],
            plugins: targetPlugins
        ),

        // crashes ----------------------------------------------------------------------
        .target(
            name: "EmbraceCrash",
            dependencies: [
                "EmbraceCommon",
                .product(name: "KSCrash", package: "KSCrash")
            ],
            plugins: targetPlugins
        ),
        .testTarget(
            name: "EmbraceCrashTests",
            dependencies: ["EmbraceCrash", "TestSupport"],
            resources: [
                .copy("Mocks/")
            ],
            plugins: targetPlugins
        ),

        // test support ----------------------------------------------------------------------
        .target(
            name: "TestSupport",
            dependencies: [.product(name: "OpenTelemetrySdk", package: "opentelemetry-swift") ],
            path: "Tests/TestSupport",
            plugins: targetPlugins
        ),

        // Utilities
        .target(name: "EmbraceObjCUtils",
                plugins: targetPlugins)
    ]
)
