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
// In remote mode, EMBRACE_APPSIZE_SDK_REF picks what to measure: a branch (default "main") or a
// release tag. A semver-looking value is resolved as an exact tag; anything else as a branch.
//
// `Package`/`Version` are ambiguous here because Tuist evaluates this manifest with `-D TUIST`, which
// imports ProjectDescription (it defines those types too) — so qualify the SwiftPM ones explicitly.
let sdkDependency: PackageDescription.Package.Dependency
if environment["EMBRACE_APPSIZE_LOCAL_SDK"] != nil {
    sdkDependency = .package(path: "../../../")
} else {
    let ref = environment["EMBRACE_APPSIZE_SDK_REF"] ?? "main"
    let url = "https://github.com/embrace-io/embrace-apple-sdk"
    if let tag = PackageDescription.Version(ref) {
        sdkDependency = .package(url: url, exact: tag)
    } else {
        sdkDependency = .package(url: url, branch: ref)
    }
}

let package = Package(
    name: "AppSizeTester",
    dependencies: [
        sdkDependency
    ]
)
