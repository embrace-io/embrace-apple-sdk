// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
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
        .library(name: "EmbraceSemantics", targets: ["EmbraceSemantics"]),
        .library(name: "EmbraceMacros", targets: ["EmbraceMacros", "EmbraceCore"]),
        .library(name: "EmbraceKSCrashSupport", targets: ["EmbraceKSCrashSupport"]),
        .library(name: "EmbraceKSCrashBacktraceSupport", targets: ["EmbraceKSCrashBacktraceSupport"]),
        .library(name: "EmbraceCrashlyticsSupport", targets: ["EmbraceCrashlyticsSupport"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/kstenerud/KSCrash",
            exact: "2.3.0"
        ),
        .package(
            url: "https://github.com/open-telemetry/opentelemetry-swift-core",
            exact: "2.1.1"
        ),
        .package(
            url: "https://github.com/swiftlang/swift-syntax.git",
            from: "509.0.0"
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
                "EmbraceSemantics",
                "EmbraceKSCrashSupport",
                "EmbraceKSCrashBacktraceSupport"
            ],
            linkerSettings: linkerSettings
        ),

        .testTarget(
            name: "EmbraceIOTests",
            dependencies: [
                "EmbraceIO",
                "EmbraceCore",
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
                "EmbraceSemantics",
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core")
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
            name: "EmbraceSemantics"
        ),

        // capture service -----------------------------------------------------------
        .target(
            name: "EmbraceCaptureService",
            dependencies: [
                "EmbraceOTelInternal",
                "EmbraceConfiguration",
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core")
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
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core")
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

        // macros support -----------------------------------------------------------
        .macro(
            name: "EmbraceMacroPlugin",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ],
            path: "Sources/EmbraceMacros/Plugins"
        ),
        .target(
            name: "EmbraceMacros",
            dependencies: [
                "EmbraceMacroPlugin",
                "EmbraceCore"
            ],
            path: "Sources/EmbraceMacros/Source"
        ),
        .testTarget(
            name: "EmbraceMacrosTests",
            dependencies: [
                "EmbraceMacroPlugin",
                "EmbraceIO",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax")
            ]
        ),

        // kscrash support  -------------------------------------------------------
        .target(
            name: "EmbraceKSCrashSupport",
            dependencies: [
                "EmbraceCommonInternal",
                .product(name: "Recording", package: "KSCrash")
            ],
            path: "Sources/ThirdParty/EmbraceKSCrashSupport"
        ),
        .target(
            name: "EmbraceKSCrashBacktraceSupport",
            dependencies: [
                "EmbraceCommonInternal",
                .product(name: "DemangleFilter", package: "KSCrash"),
                .product(name: "Recording", package: "KSCrash")
            ],
            path: "Sources/ThirdParty/EmbraceKSCrashBacktraceSupport"
        ),
        .testTarget(
            name: "EmbraceCrashTests",
            dependencies: ["EmbraceCore", "EmbraceKSCrashSupport", "EmbraceCommonInternal", "TestSupport"],
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
        .target(
            name: "EmbraceObjCUtilsInternal"
        ),
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
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core")
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
