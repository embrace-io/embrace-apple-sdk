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
        .library(name: "EmbraceSemantics", targets: ["EmbraceSemantics"]),
    ],
    dependencies: [
        .package(
             url: "https://github.com/embrace-io/KSCrash.git",
             exact: "2.0.2"
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
        ),
    ],
    targets: [
        // main target ---------------------------------------------------------------
        .target(
            name: "EmbraceIO",
            dependencies: [
                "EmbraceCaptureService",
                "EmbraceCore",
                "EmbraceCommonInternal",
                "EmbraceCrash",
                "EmbraceSemantics"
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
                "EmbraceCommonInternal",
                "EmbraceConfigInternal",
                "EmbraceOTelInternal",
                "EmbraceStorageInternal",
                "EmbraceUploadInternal",
                "EmbraceObjCUtilsInternal",
                "EmbraceSemantics"
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
            name: "EmbraceCommonInternal",
            plugins: targetPlugins
        ),
        .testTarget(
            name: "EmbraceCommonInternalTests",
            dependencies: [
                "EmbraceCommonInternal",
                "TestSupport"
            ],
            plugins: targetPlugins
        ),

        // semantics -----------------------------------------------------------------
        .target(
            name: "EmbraceSemantics",
            dependencies: [
                "EmbraceCommonInternal"
            ],
            plugins: targetPlugins
        ),

        // capture service -----------------------------------------------------------
        .target(
            name: "EmbraceCaptureService",
            dependencies: [
                "EmbraceOTelInternal",
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
            name: "EmbraceConfigInternal",
            dependencies: [
                "EmbraceCommonInternal"
            ],
            plugins: targetPlugins
        ),

        .testTarget(
            name: "EmbraceConfigInternalTests",
            dependencies: [
                "EmbraceConfigInternal",
                "TestSupport"
            ],
            resources: [
                .copy("Mocks/")
            ],
            plugins: targetPlugins
        ),

        // OTel ----------------------------------------------------------------------
        .target(
            name: "EmbraceOTelInternal",
            dependencies: [
                "EmbraceCommonInternal",
                "EmbraceSemantics",
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift")
            ],
            plugins: targetPlugins
        ),
        .testTarget(
            name: "EmbraceOTelInternalTests",
            dependencies: [
                "EmbraceOTelInternal",
                "TestSupport"
            ],
            plugins: targetPlugins
        ),

        // storage -------------------------------------------------------------------
        .target(
            name: "EmbraceStorageInternal",
            dependencies: [
                "EmbraceCommonInternal",
                "EmbraceSemantics",
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            plugins: targetPlugins
        ),
        .testTarget(
            name: "EmbraceStorageInternalTests",
            dependencies: ["EmbraceStorageInternal", "TestSupport"],
            resources: [
                .copy("Mocks/")
            ],
            plugins: targetPlugins
        ),

        // upload --------------------------------------------------------------------
        .target(
            name: "EmbraceUploadInternal",
            dependencies: [
                "EmbraceCommonInternal",
                "EmbraceOTelInternal",
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            plugins: targetPlugins
        ),
        .testTarget(
            name: "EmbraceUploadInternalTests",
            dependencies: [
                "EmbraceUploadInternal",
                "EmbraceOTelInternal",
                "TestSupport"
            ],
            plugins: targetPlugins
        ),

        // crashes -------------------------------------------------------------------
        .target(
            name: "EmbraceCrash",
            dependencies: [
                "EmbraceCommonInternal",
                .product(name: "Recording", package: "KSCrash")
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
                "EmbraceCommonInternal"
            ],
            path: "Sources/ThirdParty/EmbraceCrashlyticsSupport",
            plugins: targetPlugins
        ),
        .testTarget(
            name: "EmbraceCrashlyticsSupportTests",
            dependencies: ["EmbraceCrashlyticsSupport", "EmbraceCommonInternal", "TestSupport"],
            path: "Tests/ThirdParty/EmbraceCrashlyticsSupportTests",
            plugins: targetPlugins
        ),

        // Utilities
        .target(name: "EmbraceObjCUtilsInternal",
                plugins: targetPlugins),
        .testTarget(
            name: "EmbraceObjCUtilsInternalTests",
            dependencies: ["EmbraceObjCUtilsInternal", "TestSupport"],
            plugins: targetPlugins
        ),

        // test support --------------------------------------------------------------
        .target(
            name: "TestSupport",
            dependencies: [
                "EmbraceCore",
                "EmbraceOTelInternal",
                "EmbraceCommonInternal",
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift")
            ],
            path: "Tests/TestSupport",
            plugins: targetPlugins
        )
    ]
)
