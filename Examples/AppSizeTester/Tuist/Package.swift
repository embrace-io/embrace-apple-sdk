// swift-tools-version: 5.9
import PackageDescription

#if TUIST
    import ProjectDescription

    let packageSettings = PackageSettings(
        productTypes: [:]
    )
#endif

let package = Package(
    name: "AppSizeTester",
    dependencies: [
        .package(
            path: "../../../"
        )
    ]
)
