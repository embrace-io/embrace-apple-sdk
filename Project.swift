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
            sources: ["Sources/EmbraceIO/**"],
            dependencies: [
                .target(name: "EmbraceCaptureService"),
                .target(name: "EmbraceCore"),
                .target(name: "EmbraceCommonInternal"),
                .target(name: "EmbraceCrash"),
                .target(name: "EmbraceSemantics")
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
                .target(name: "EmbraceSemantics")
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
            sources: ["Sources/EmbraceSemantics/**"],
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
            sources: ["Sources/EmbraceConfigInternal/**"],
            dependencies: [
                .target(name: "EmbraceCommonInternal")
            ],
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
            sources: ["Sources/EmbraceUploadInternal/**"],
            dependencies: [
                .target(name: "EmbraceCommonInternal"),
                .target(name: "EmbraceOTelInternal"),
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
            name: "EmbraceObjCUtilsInternal",
            destinations: .iOS,
            product: .framework,
            bundleId: "com.embraceio.EmbraceObjCUtilsInternal",
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
