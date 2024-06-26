// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

var targetPlugins: [Target.PluginUsage] = [.plugin(name: "SwiftLintPlugin", package: "SwiftLint")]
// Work around for plugin dependency being included in iOS target when using `xcodebuild test`
// (See bin/xctest)
// https://forums.swift.org/t/xcode-attempts-to-build-plugins-for-ios-is-there-a-workaround/57029
if ProcessInfo.processInfo.environment["IS_XCTEST"] != nil ||
    ProcessInfo.processInfo.environment["IS_ARCHIVE"] != nil {
    targetPlugins.removeAll()
}

let package = Package(
    name: "EmbraceIO",
    platforms: [
        .iOS(.v13), .tvOS(.v13), .macOS(.v13), .watchOS(.v6)
    ],
    products: [
        .library(name: "EmbraceIO", targets: ["EmbraceIO"]),
        .library(name: "EmbraceCore", targets: ["EmbraceCore"]),
        .library(name: "EmbraceCrash", targets: ["EmbraceCrash"]),
        .library(name: "EmbraceCrashlyticsSupport", targets: ["EmbraceCrashlyticsSupport"]),
        .library(name: "EmbraceIO-Dynamic", type: .dynamic, targets: ["EmbraceIO"]),
        .library(name: "EmbraceCore-Dynamic", type: .dynamic, targets: ["EmbraceCore"]),
        .library(name: "EmbraceCrash-Dynamic", type: .dynamic, targets: ["EmbraceCrash"]),
        .library(name: "EmbraceCrashlyticsSupport-Dynamic", type: .dynamic, targets: ["EmbraceCrashlyticsSupport"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/embrace-io/KSCrash.git",
            exact: "1.16.0"
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
        // main target ---------------------------------------------------------------
        .target(
            name: "EmbraceIO",
            dependencies: [
                "EmbraceCaptureService",
                "EmbraceCore",
                "EmbraceCommon",
                "EmbraceCrash"
            ],
            plugins: targetPlugins
        ),

        .testTarget(
            name: "EmbraceIOTests",
            dependencies: [
                "EmbraceIO",
                "EmbraceCore",
                "EmbraceCrash",
                "TestSupport",
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            plugins: targetPlugins
        ),

        // core ----------------------------------------------------------------------
        .target(
            name: "EmbraceCore",
            dependencies: [
                "EmbraceCaptureService",
                "EmbraceCommon",
                "EmbraceConfig",
                "EmbraceOTel",
                "EmbraceStorage",
                "EmbraceUpload",
                "EmbraceObjCUtils",
                .product(name: "Gzip", package: "GzipSwift")
            ],
            resources: [
                .copy("PrivacyInfo.xcprivacy")
            ],
            plugins: targetPlugins
        ),

        .testTarget(
            name: "EmbraceCoreTests",
            dependencies: [
                "EmbraceCore",
                "TestSupport",
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            resources: [
                .copy("Mocks/")
            ],
            plugins: targetPlugins
        ),

        // common --------------------------------------------------------------------
        .target(
            name: "EmbraceCommon",
            plugins: targetPlugins
        ),
        .testTarget(
            name: "EmbraceCommonTests",
            dependencies: [
                "EmbraceCommon",
                "TestSupport"
            ],
            plugins: targetPlugins
        ),

        // capture service -----------------------------------------------------------
        .target(
            name: "EmbraceCaptureService",
            dependencies: [
                "EmbraceOTel",
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift")
            ],
            plugins: targetPlugins
        ),
        .testTarget(
            name: "EmbraceCaptureServiceTests",
            dependencies: [
                "EmbraceCaptureService",
                "TestSupport"
            ],
            plugins: targetPlugins
        ),

        // config --------------------------------------------------------------------
        .target(
            name: "EmbraceConfig",
            dependencies: [
                "EmbraceCommon"
            ],
            plugins: targetPlugins
        ),

        .testTarget(
            name: "EmbraceConfigTests",
            dependencies: [
                "EmbraceConfig",
                "TestSupport"
            ],
            resources: [
                .copy("Mocks/")
            ],
            plugins: targetPlugins
        ),

        // OTel ----------------------------------------------------------------------
        .target(
            name: "EmbraceOTel",
            dependencies: [
                "EmbraceCommon",
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift")
            ],
            plugins: targetPlugins
        ),
        .testTarget(
            name: "EmbraceOTelTests",
            dependencies: [
                "EmbraceOTel",
                "TestSupport"
            ],
            plugins: targetPlugins
        ),

        // storage -------------------------------------------------------------------
        .target(
            name: "EmbraceStorage",
            dependencies: [
                "EmbraceCommon",
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            plugins: targetPlugins
        ),
        .testTarget(
            name: "EmbraceStorageTests",
            dependencies: ["EmbraceStorage", "TestSupport"],
            resources: [
                .copy("Mocks/")
            ],
            plugins: targetPlugins
        ),

        // upload --------------------------------------------------------------------
        .target(
            name: "EmbraceUpload",
            dependencies: [
                "EmbraceCommon",
                "EmbraceOTel",
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            plugins: targetPlugins
        ),
        .testTarget(
            name: "EmbraceUploadTests",
            dependencies: [
                "EmbraceUpload",
                "EmbraceOTel",
                "TestSupport"
            ],
            plugins: targetPlugins
        ),

        // crashes -------------------------------------------------------------------
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

        // crashlytics support  -------------------------------------------------------
        .target(
            name: "EmbraceCrashlyticsSupport",
            dependencies: [
                "EmbraceCommon"
            ],
            path: "Sources/ThirdParty/EmbraceCrashlyticsSupport",
            plugins: targetPlugins
        ),
        .testTarget(
            name: "EmbraceCrashlyticsSupportTests",
            dependencies: ["EmbraceCrashlyticsSupport", "EmbraceCommon", "TestSupport"],
            path: "Tests/ThirdParty/EmbraceCrashlyticsSupportTests",
            plugins: targetPlugins
        ),

        // Utilities
        .target(name: "EmbraceObjCUtils",
                plugins: targetPlugins),
        .testTarget(
            name: "EmbraceObjCUtilsTests",
            dependencies: ["EmbraceObjCUtils", "TestSupport"],
            plugins: targetPlugins
        ),

        // test support --------------------------------------------------------------
        .target(
            name: "TestSupport",
            dependencies: [
                "EmbraceCore",
                "EmbraceOTel",
                "EmbraceCommon",
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift")
            ],
            path: "Tests/TestSupport",
            plugins: targetPlugins
        )
    ]
)
