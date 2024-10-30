import ProjectDescription

let project = Project(
    name: "AppSizeTester",
    targets: [
        .target(
            name: "AppSizeTester",
            destinations: .iOS,
            product: .app,
            bundleId: "com.embraceio.AppSizeTester",
            deploymentTargets: .iOS("13.0"),
            infoPlist: .extendingDefault(
                with: [
                    "UILaunchScreen": [
                        "UIColorName": "",
                        "UIImageName": "",
                    ],
                ]
            ),
            sources: ["AppSizeTester/Sources/**"],
            resources: ["AppSizeTester/Resources/**"],
            dependencies: [],
            settings: .settings(
                base: .init().automaticCodeSigning(devTeam: "L5RVT7J8CV"),
                configurations: [
                    .debug(name: "Debug"),
                    .release(name: "Release"),
                ]
            )
        ),
        .target(
            name: "AppSizeTesterWithSDK",
            destinations: .iOS,
            product: .app,
            bundleId: "com.embraceio.AppSizeTesterWithSDK",
            deploymentTargets: .iOS("13.0"),
            infoPlist: .extendingDefault(
                with: [
                    "UILaunchScreen": [
                        "UIColorName": "",
                        "UIImageName": "",
                    ],
                ]
            ),
            sources: ["AppSizeTester/Sources/**"],
            resources: ["AppSizeTester/Resources/**"],
            dependencies: [
                .external(name: "EmbraceIO"),
                .external(name: "EmbraceCore"),
                .external(name: "EmbraceSemantics"),
                .external(name: "EmbraceCrash"),
            ],
            settings: .settings(
                base: .init().automaticCodeSigning(devTeam: "L5RVT7J8CV"),
                configurations: [
                    .debug(name: "DebugWithSDK"),
                    .release(name: "ReleaseWithSDK"),
                ]
            )
        ),
    ],
    schemes: [
        .scheme(
            name: "AppSizeTester",
            buildAction: .buildAction(targets: ["AppSizeTester"]),
            runAction: .runAction(executable: "AppSizeTester")
        ),
        .scheme(
            name: "AppSizeTesterWithSDK",
            buildAction: .buildAction(targets: ["AppSizeTesterWithSDK"]),
            runAction: .runAction(executable: "AppSizeTesterWithSDK")
        )
    ]
)
