// swift-tools-version: 5.9
import Foundation
import PackageDescription

#if TUIST
    import ProjectDescription

    let packageSettings = PackageSettings(
        productTypes: [:]
    )
#endif

let environment = ProcessInfo.processInfo.environment

// The SDK dependency is resolved remotely by default so the project generates with current Tuist.
//
// Set EMBRACE_APPSIZE_LOCAL_SDK=1 to instead build the working-tree SDK (../../../) — useful for
// measuring uncommitted changes. That path requires Tuist <= 4.181.1: Tuist 4.182.0 added "preserve
// test targets for local SPM packages", which pulls the SDK's test targets into the graph; those
// depend on the test-only `TestSupport` helper (which Tuist ignores by product type), so generation
// fails. Remote dependencies are not affected by that feature.
//
// In remote mode, EMBRACE_APPSIZE_SDK_REF overrides the branch (default "main").
// `Package` is ambiguous here because Tuist evaluates this manifest with `-D TUIST`, which imports
// ProjectDescription (it also defines a `Package` type) — so qualify the SwiftPM one explicitly.
let sdkDependency: PackageDescription.Package.Dependency
if environment["EMBRACE_APPSIZE_LOCAL_SDK"] != nil {
    sdkDependency = .package(path: "../../../")
} else {
    let ref = environment["EMBRACE_APPSIZE_SDK_REF"] ?? "main"
    sdkDependency = .package(url: "https://github.com/embrace-io/embrace-apple-sdk", branch: ref)
}

let package = Package(
    name: "AppSizeTester",
    dependencies: [
        sdkDependency
    ]
)
