import ProjectDescription

let project = Project(
    name: "EmbraceIO",
    organizationName: "com.embraceio",
    targets: [
        .target(
            name: "EmbraceIO",
            destinations: .iOS,
            product: .framework,
            bundleId: "com.embraceio.EmbraceIO",
            deploymentTargets: .iOS("13.0"),
            sources: ["Sources/EmbraceIO/**"],
            dependencies: [
                .target(name: "EmbraceCaptureService"),
                .target(name: "EmbraceCore"),
                .target(name: "EmbraceCommonInternal"),
                .target(name: "EmbraceCrash"),
                .target(name: "EmbraceSemantics"),
                .target(name: "EmbraceConfiguration")
            ],
            settings: .settings(base: [
                "SKIP_INSTALL": "NO",
                "BUILD_LIBRARY_FOR_DISTRIBUTION": "YES"
            ])
        ),
        .target(
            name: "EmbraceCore",
            destinations: .iOS,
            product: .framework,
            bundleId: "com.embraceio.EmbraceCore",
            deploymentTargets: .iOS("13.0"),
            sources: ["Sources/EmbraceCore/**"],
            resources: ["Sources/EmbraceCore/PrivacyInfo.xcprivacy"],
            dependencies: [
                .target(name: "EmbraceCaptureService"),
                .target(name: "EmbraceCommonInternal"),
                .target(name: "EmbraceConfigInternal"),
                .target(name: "EmbraceOTelInternal"),
                .target(name: "EmbraceStorageInternal"),
                .target(name: "EmbraceUploadInternal"),
                .target(name: "EmbraceObjCUtilsInternal"),
                .target(name: "EmbraceSemantics"),
                .target(name: "EmbraceConfiguration")
            ],
            settings: .settings(base: [
                "HEADER_SEARCH_PATHS": ["$(SRCROOT)/Sources/EmbraceObjCUtilsInternal/include"],
                // See if `-lz` is really necessary
                "OTHER_LDFLAGS": ["-lc++ -lz"],
                "SKIP_INSTALL": "NO",
                "BUILD_LIBRARY_FOR_DISTRIBUTION": "YES"
            ])
        ),
        .target(
            name: "EmbraceCommonInternal",
            destinations: .iOS,
            product: .framework,
            bundleId: "com.embraceio.EmbraceCommonInternal",
            deploymentTargets: .iOS("13.0"),
            sources: ["Sources/EmbraceCommonInternal/**"],
            settings: .settings(base: [
                "SKIP_INSTALL": "NO",
                "BUILD_LIBRARY_FOR_DISTRIBUTION": "YES"
            ])
        ),
        .target(
            name: "EmbraceSemantics",
            destinations: .iOS,
            product: .framework,
            bundleId: "com.embraceio.EmbraceSemantics",
            deploymentTargets: .iOS("13.0"),
            sources: ["Sources/EmbraceSemantics/**"],
            dependencies: [
                .target(name: "EmbraceCommonInternal"),
                .external(name: "OpenTelemetrySdk")
            ],
            settings: .settings(base: [
                "SKIP_INSTALL": "NO",
                "BUILD_LIBRARY_FOR_DISTRIBUTION": "YES"
            ])
        ),
        .target(
            name: "EmbraceCaptureService",
            destinations: .iOS,
            product: .framework,
            bundleId: "com.embraceio.EmbraceCaptureService",
            deploymentTargets: .iOS("13.0"),
            sources: ["Sources/EmbraceCaptureService/**"],
            dependencies: [
                .target(name: "EmbraceOTelInternal"),
                .external(name: "OpenTelemetrySdk")
            ],
            settings: .settings(base: [
                "SKIP_INSTALL": "NO",
                "BUILD_LIBRARY_FOR_DISTRIBUTION": "YES"
            ])
        ),
        .target(
            name: "EmbraceConfigInternal",
            destinations: .iOS,
            product: .framework,
            bundleId: "com.embraceio.EmbraceConfigInternal",
            deploymentTargets: .iOS("13.0"),
            sources: ["Sources/EmbraceConfigInternal/**"],
            dependencies: [
                .target(name: "EmbraceCommonInternal"),
                .target(name: "EmbraceConfiguration")
            ],
            settings: .settings(base: [
                "SKIP_INSTALL": "NO",
                "BUILD_LIBRARY_FOR_DISTRIBUTION": "YES"
            ])
        ),
        .target(
            name: "EmbraceConfiguration",
            destinations: .iOS,
            product: .framework,
            bundleId: "com.embraceio.EmbraceConfiguration",
            deploymentTargets: .iOS("13.0"),
            sources: ["Sources/EmbraceConfiguration/**"],
            dependencies: [],
            settings: .settings(base: [
                "SKIP_INSTALL": "NO",
                "BUILD_LIBRARY_FOR_DISTRIBUTION": "YES"
            ])
        ),
        .target(
            name: "EmbraceOTelInternal",
            destinations: .iOS,
            product: .framework,
            bundleId: "com.embraceio.EmbraceOTelInternal",
            deploymentTargets: .iOS("13.0"),
            sources: ["Sources/EmbraceOTelInternal/**"],
            dependencies: [
                .target(name: "EmbraceCommonInternal"),
                .target(name: "EmbraceSemantics"),
                .external(name: "OpenTelemetrySdk")
            ],
            settings: .settings(base: [
                "SKIP_INSTALL": "NO",
                "BUILD_LIBRARY_FOR_DISTRIBUTION": "YES"
            ])
        ),
        .target(
            name: "EmbraceStorageInternal",
            destinations: .iOS,
            product: .framework,
            bundleId: "com.embraceio.EmbraceStorageInternal",
            deploymentTargets: .iOS("13.0"),
            sources: ["Sources/EmbraceStorageInternal/**"],
            dependencies: [
                .target(name: "EmbraceCommonInternal"),
                .target(name: "EmbraceSemantics"),
                .external(name: "OpenTelemetryApi"),
                .external(name: "GRDB")
            ],
            settings: .settings(base: [
                "SKIP_INSTALL": "NO",
                "BUILD_LIBRARY_FOR_DISTRIBUTION": "YES"
            ])
        ),
        .target(
            name: "EmbraceUploadInternal",
            destinations: .iOS,
            product: .framework,
            bundleId: "com.embraceio.EmbraceUploadInternal",
            deploymentTargets: .iOS("13.0"),
            sources: ["Sources/EmbraceUploadInternal/**"],
            dependencies: [
                .target(name: "EmbraceCommonInternal"),
                .target(name: "EmbraceOTelInternal"),
                .target(name: "EmbraceCoreDataInternal"),
                .external(name: "GRDB")
            ],
            settings: .settings(base: [
                "SKIP_INSTALL": "NO",
                "BUILD_LIBRARY_FOR_DISTRIBUTION": "YES"
            ])
        ),
        .target(
            name: "EmbraceCrashlyticsSupport",
            destinations: .iOS,
            product: .framework,
            bundleId: "com.embraceio.EmbraceCrashlyticsSupport",
            deploymentTargets: .iOS("13.0"),
            sources: ["Sources/ThirdParty/EmbraceCrashlyticsSupport/**"],
            dependencies: [
                .target(name: "EmbraceCommonInternal")
            ],
            settings: .settings(base: [
                "SKIP_INSTALL": "NO",
                "BUILD_LIBRARY_FOR_DISTRIBUTION": "YES"
            ])
        ),
        .target(
            name: "EmbraceCrash",
            destinations: .iOS,
            product: .framework,
            bundleId: "com.embraceio.EmbraceCrash",
            deploymentTargets: .iOS("13.0"),
            sources: ["Sources/EmbraceCrash/**"],
            dependencies: [
                .target(name: "EmbraceCommonInternal"),
                .external(name: "Recording")
            ],
            settings: .settings(base: [
                "OTHER_LDFLAGS": ["-lc++"],
                "SKIP_INSTALL": "NO",
                "BUILD_LIBRARY_FOR_DISTRIBUTION": "YES"
            ])
        ),
        .target(
            name: "EmbraceCoreDataInternal",
            destinations: .iOS,
            product: .framework,
            bundleId: "com.embraceio.EmbraceCoreDataInternal",
            deploymentTargets: .iOS("13.0"),
            sources: ["Sources/EmbraceCoreDataInternal/**"],
            dependencies: [
                .target(name: "EmbraceCommonInternal"),
            ],
            settings: .settings(base: [
                "SKIP_INSTALL": "NO",
                "BUILD_LIBRARY_FOR_DISTRIBUTION": "YES"
            ])
        ),
        .target(
            name: "EmbraceObjCUtilsInternal",
            destinations: .iOS,
            product: .framework,
            bundleId: "com.embraceio.EmbraceObjCUtilsInternal",
            deploymentTargets: .iOS("13.0"),
            sources: ["Sources/EmbraceObjCUtilsInternal/**"],
            headers: .headers(public: "Sources/EmbraceObjCUtilsInternal/include/**/*.h"),
            settings: .settings(base: [
                "HEADER_SEARCH_PATHS": ["$(SRCROOT)/Sources/EmbraceObjCUtilsInternal/include"],
                "MODULEMAP_FILE": "$(SRCROOT)/Sources/EmbraceObjCUtilsInternal/include/module.modulemap",
                "SKIP_INSTALL": "NO",
                "BUILD_LIBRARY_FOR_DISTRIBUTION": "YES"
            ])
        )
    ]
)
