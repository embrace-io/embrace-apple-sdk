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
            url: "https://github.com/embrace-io/embrace-apple-sdk.git",
            exact: "6.5.0"
        )
    ]
)
