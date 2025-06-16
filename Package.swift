// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

#if TUIST
    import ProjectDescription

    let packageSettings = PackageSettings(
        productTypes: [
            "KSCrash": .framework,
            "OpenTelemetrySdk": .framework,
            "OpenTelemetryApi": .framework
        ]
    )
#endif

var linkerSettings: [LinkerSetting]?

// This applies only to targets like EmbraceCore and EmbraceIO that contain `@objc extensions`.
// When linked statically (as Tuist tends to do when installing Embrace via SPM packages),
// selectors from these extensions are stripped unless `-ObjC` is passed explicitly to the linker.
if ProcessInfo.processInfo.environment["EMBRACE_ENABLE_TUIST_OBJC_LINK"] != nil {
    linkerSettings = [.unsafeFlags(["-ObjC"])]
}

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
             url: "https://github.com/kstenerud/KSCrash",
             .upToNextMinor(from: "2.2.0")
        ),
        .package(
            url: "https://github.com/open-telemetry/opentelemetry-swift",
            exact: "1.13.0"
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
            ],
            linkerSettings: linkerSettings
        ),

        .testTarget(
            name: "EmbraceIOTests",
            dependencies: [
                "EmbraceIO",
                "EmbraceCore",
                "EmbraceCrash",
                "TestSupport"
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
           ],
           linkerSettings: linkerSettings
        ),

        .testTarget(
            name: "EmbraceCoreTests",
            dependencies: [
                "EmbraceCore",
                "TestSupport",
                "TestSupportObjc"
            ],
            resources: [
                .copy("Mocks/")
            ]
        ),

        // common --------------------------------------------------------------------
        .target(
            name: "EmbraceCommonInternal",
            dependencies: [
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift")
            ]
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
                "EmbraceCommonInternal",
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift")
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
                "EmbraceCoreDataInternal",
                "EmbraceSemantics"
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
                "EmbraceCoreDataInternal"
            ]
        ),
        .testTarget(
            name: "EmbraceUploadInternalTests",
            dependencies: [
                "EmbraceUploadInternal",
                "EmbraceOTelInternal",
                "EmbraceCoreDataInternal",
                "TestSupport"
            ]
        ),

        // core data -----------------------------------------------------------------
        .target(
            name: "EmbraceCoreDataInternal",
            dependencies: [
                "EmbraceCommonInternal"
            ]
        ),
        .testTarget(
            name: "EmbraceCoreDataInternalTests",
            dependencies: [
                "EmbraceCommonInternal",
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
            path: "Tests/TestSupport",
            exclude: ["Objc"]
        ),
        .target(
            name: "TestSupportObjc",
            path: "Tests/TestSupport/Objc"
        )
    ]
)

if ProcessInfo.processInfo.environment["EMBRACE_ENABLE_SWIFTLINT"] != nil {
  package.dependencies.append(contentsOf: [
    .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", from: "0.58.2")
  ])

  for target in package.targets {
    target.plugins = [
      .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")
    ]
  }
}
