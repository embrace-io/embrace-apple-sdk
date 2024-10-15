// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
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
    products: [
        .library(name: "EmbraceIO", targets: ["EmbraceIO"]),
        .library(name: "EmbraceCore", targets: ["EmbraceCore", "EmbraceConfiguration"]),
        .library(name: "EmbraceCrash", targets: ["EmbraceCrash"]),
        .library(name: "EmbraceCrashlyticsSupport", targets: ["EmbraceCrashlyticsSupport"]),
        .library(name: "EmbraceSemantics", targets: ["EmbraceSemantics"])
    ],
    dependencies: [
        .package(
             url: "https://github.com/embrace-io/KSCrash.git",
             exact: "2.0.4"
        ),
        .package(
            url: "https://github.com/open-telemetry/opentelemetry-swift",
            exact: "1.10.1"
        ),
        .package(
            url: "https://github.com/groue/GRDB.swift",
            exact: "6.29.1"
        )
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
            ]
        ),

        .testTarget(
            name: "EmbraceIOTests",
            dependencies: [
                "EmbraceIO",
                "EmbraceCore",
                "EmbraceCrash",
                "TestSupport",
                .product(name: "GRDB", package: "GRDB.swift")
            ]
        ),

        // core ----------------------------------------------------------------------
        .target(
            name: "EmbraceCore",
            dependencies: [
                "EmbraceCaptureService",
                "EmbraceCommonInternal",
                "EmbraceConfigInternal",
                "EmbraceConfiguration",
                "EmbraceOTelInternal",
                "EmbraceStorageInternal",
                "EmbraceUploadInternal",
                "EmbraceObjCUtilsInternal",
                "EmbraceSemantics"
            ],
            resources: [
                .copy("PrivacyInfo.xcprivacy")
            ]
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
            ]
        ),

        // common --------------------------------------------------------------------
        .target(
            name: "EmbraceCommonInternal"
        ),
        .testTarget(
            name: "EmbraceCommonInternalTests",
            dependencies: [
                "EmbraceCommonInternal",
                "TestSupport"
            ]
        ),

        // semantics -----------------------------------------------------------------
        .target(
            name: "EmbraceSemantics",
            dependencies: [
                "EmbraceCommonInternal"
            ]
        ),

        // capture service -----------------------------------------------------------
        .target(
            name: "EmbraceCaptureService",
            dependencies: [
                "EmbraceOTelInternal",
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift")
            ]
        ),
        .testTarget(
            name: "EmbraceCaptureServiceTests",
            dependencies: [
                "EmbraceCaptureService",
                "TestSupport"
            ]
        ),

        // config --------------------------------------------------------------------
        .target(
            name: "EmbraceConfiguration",
            dependencies: []
        ),

        .testTarget(
            name: "EmbraceConfigurationTests",
            dependencies: [
                "EmbraceConfiguration"
            ]
        ),

        .target(
            name: "EmbraceConfigInternal",
            dependencies: [
                "EmbraceCommonInternal",
                "EmbraceConfiguration"
            ]
        ),

        .testTarget(
            name: "EmbraceConfigInternalTests",
            dependencies: [
                "EmbraceConfigInternal",
                "TestSupport"
            ],
            resources: [
                .copy("Fixtures")
            ]
        ),

        // OTel ----------------------------------------------------------------------
        .target(
            name: "EmbraceOTelInternal",
            dependencies: [
                "EmbraceCommonInternal",
                "EmbraceSemantics",
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift")
            ]
        ),
        .testTarget(
            name: "EmbraceOTelInternalTests",
            dependencies: [
                "EmbraceOTelInternal",
                "TestSupport"
            ]
        ),

        // storage -------------------------------------------------------------------
        .target(
            name: "EmbraceStorageInternal",
            dependencies: [
                "EmbraceCommonInternal",
                "EmbraceSemantics",
                .product(name: "GRDB", package: "GRDB.swift")
            ]
        ),
        .testTarget(
            name: "EmbraceStorageInternalTests",
            dependencies: ["EmbraceStorageInternal", "TestSupport"],
            resources: [
                .copy("Mocks/")
            ]
        ),

        // upload --------------------------------------------------------------------
        .target(
            name: "EmbraceUploadInternal",
            dependencies: [
                "EmbraceCommonInternal",
                "EmbraceOTelInternal",
                .product(name: "GRDB", package: "GRDB.swift")
            ]
        ),
        .testTarget(
            name: "EmbraceUploadInternalTests",
            dependencies: [
                "EmbraceUploadInternal",
                "EmbraceOTelInternal",
                "TestSupport"
            ]
        ),

        // crashes -------------------------------------------------------------------
        .target(
            name: "EmbraceCrash",
            dependencies: [
                "EmbraceCommonInternal",
                .product(name: "Recording", package: "KSCrash")
            ]
        ),
        .testTarget(
            name: "EmbraceCrashTests",
            dependencies: ["EmbraceCrash", "TestSupport"],
            resources: [
                .copy("Mocks/")
            ]
        ),

        // crashlytics support  -------------------------------------------------------
        .target(
            name: "EmbraceCrashlyticsSupport",
            dependencies: [
                "EmbraceCommonInternal"
            ],
            path: "Sources/ThirdParty/EmbraceCrashlyticsSupport"
        ),
        .testTarget(
            name: "EmbraceCrashlyticsSupportTests",
            dependencies: ["EmbraceCrashlyticsSupport", "EmbraceCommonInternal", "TestSupport"],
            path: "Tests/ThirdParty/EmbraceCrashlyticsSupportTests"
        ),

        // Utilities
        .target(name: "EmbraceObjCUtilsInternal"),
        .testTarget(
            name: "EmbraceObjCUtilsInternalTests",
            dependencies: ["EmbraceObjCUtilsInternal", "TestSupport"]
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
            path: "Tests/TestSupport"
        )
    ]
)
