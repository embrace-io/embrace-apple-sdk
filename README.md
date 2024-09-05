# Embrace Apple SDK

The Embrace Apple SDK instruments your iOS, iPadOS, tvOS, visionOS, and watchOS* apps to collect observability data.
This project represents a shift from the previous Embrace SDK in that it adopts a more modular approach that
supports the [OpenTelemetry](https://opentelemetry.io/) standard. We have also added features that extend OpenTelemetry to
better support mobile apps.

Telemetry recorded through this SDK can be consumed on the Embrace platform for Embrace customers, but it can also be used by those who are not Embrace customers to export collected data directly to any OTel Collector, either one that they host or is hosted by other vendors. In effect, this SDK is an alternative to using the [OpenTelemetry Swift SDK](https://github.com/open-telemetry/opentelemetry-swift) directly for iOS apps that want to leverage the OpenTelemetry ecosystem for observability, but also want all the advanced telemetry capture that Embrace is known for. 

Currently, only Spans and Logs are supported, but other signals will be added in the future.

More documentation and examples can be found at [https://embrace.io/docs/](https://embrace.io/docs/).

## Features

### Currently Supported Key Features

* Session capture
* Crash capture 
* Network capture
* OTel trace capture
* Custom breadcrumbs
* Custom logs
* OpenTelemetry Export
* Session properties
* Automatic view tracking

### Key Features Coming Soon

* Metrickit capture
* Network payload capture
* Extensions insights

## Getting Started

For a more detailed walkthrough, check the [GETTING_STARTED](./GETTING_STARTED.md) doc. You can also open the **BrandGame** project under `Examples/BrandGame` to see an app that is already setup and using the EmbraceIO package.

---

Here is a quick overview to start using the Embrace SDK. You'll need to:
1. Import the `EmbraceIO` module
1. Create an instance of the Embrace client by passing `Embrace.Options` to the `setup` method.
1. Call the `start` method on that instance

This should be done as early as possible in the runtime of your app, for instance, the `UIApplicationDelegate.applicationDidFinishLaunching(_:)`
could be a good place.

Here is a code snippet:

```swift
import EmbraceIO
// ...

func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    do {
      try Embrace.setup(options: .init(appId: "myApp"))
      try Embrace.client?.start()
    } catch {
      // Unable to start Embrace
    }

    return true
}
```

Its also possible to chain these calls as `setup` will return the `Embrace.client` instance:
```swift
import EmbraceIO
// ...

func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    do {
      try Embrace
        .setup( .init(appId: "myApp") )
        .start()

    } catch {
      // Unable to start Embrace
    }

    return true
}
```

### Do I have to try?

It is unlikely that the SDK will fail during startup, but it is possible. The most notable reasons are is no space left on disk to create
our data stores or these data stores may have become corrupt. The interface accounts for these edge cases and will throw an error if they occur.

The `Embrace.client` instance will return `nil` if `setup` has never been called or if `setup` throws an error. Its possible to use Swift's "Optional try"
in order to make this entry point as concise as possible:

```swift
import EmbraceIO
// ...

func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    try? Embrace
        .setup(options: .init(appId: "myApp"))
        .start()

    // Can leverage optional behavior if desired
    let span = Embrace.client?.buildSpan("app-did-finish-launching", type: .performance)
    // ...
    span?.end()

    return true
}
```

### What's next?

Now that you're Embrace instance is setup and started, its time to add some custom instrumentation! See the full list of features in our docs
below, but here are some quick examples:

**Creating a span:**
```swift
let span = Embrace.client?
  .buildSpan(name: "my-custom-operation", type: .performance)
  .markAsKeySpan()
  .startSpan()

// perform `my-custom-operation`

span?.end()
```

**Adding User data:**
```swift
Embrace.client?.metadata.userEmail = "testing.email@my-org.com"
Embrace.client?.metadata.userIdentifier = "827B02FE-D868-461D-8B4A-FE7371818369"
Embrace.client?.metadata.userName = "tony.the.tester"
````

## Prerequisites

### Github

We are using our own KSCrash fork, so we need to set up Github credentials in Xcode to provide the required access.

* Go to the "Accounts" tab in "Settings" (`cmd+,`)
* Verify you have Github credentials saved, or click the `+` sign to add Github credentials.

## Building and Running Tests

Open the project in Xcode by either selecting the directory or the `Package.swift` file itself. If opening for the first time, Xcode may take a bit to resolve the Package Dependencies and index the project.

To build the project, select the `EmbraceIO-Package` scheme and in the menu select `Product -> Build (⌘+B)`.

### Testing

To run tests in Xcode, select the `EmbraceIO-Package` scheme and in the menu select `Product -> Test (⌘+U)`. You can also open the `Test Navigator (⌘+6)` and run individual tests using Xcode's UI.

There is also the `bin/test` command that can be used to run tests from the command line. It is recommended to pipe this through `xcpretty`.

```sh
bin/test | xcpretty
```

## Linting and Guidelines

We use [SwiftLint](https://github.com/realm/SwiftLint) to enforce them and every pull request must satisfy them to be merged.
SwiftLint is used as a plugin in all of our targets to get warnings and errors directly in Xcode.

You can run the swiftlint plugin from the CLI as well:
```sh
swift run swiftlint --fix
```

### Using SwiftLint

Aside from the warnings and errors that will appear directly in Xcode, you can use SwiftLint to automatically correct some issues.
For this first you'll need to install SwiftLint in your local environment. Follow [SwiftLint's GitHub page](https://github.com/realm/SwiftLint) to see all available options.

* Use `swiftlint lint --strict` to get a report on all the issues.
* Use `swiftlint --fix` to fix issues automatically when possible.

### Setup pre-commit hook

We strongly recommend to use a pre-commit hook to make sure all the modified files follow the guidelines before pushing.
We have provided an example pre-commit hook in `.githooks/pre-commit`. Note that depending on your local environment, you might need to edit the pre-commit file to set the path to `swiftlint`.

**Alternatives on how to setup the hook:**
* Simply copy `.githooks/pre-commit` into `.git/hooks/pre-commit`.
* Use the `core.hooksPath` setting to change the hooks path (`git config core.hooksPath .githooks`)


## Troubleshooting

### Github auth issues

If you cannot fetch the `KSCrash` dependency, you most likely have Github auth issues.

1. Verify you have set up Github credentials in on the "Accounts" tab in "Settings"
2. Enter the passcode for your SSH key on that page if prompted to do so.
3. If you have the following in your `.gitconfig`, remove it since Xcode apparently does not handle this

```
[url "ssh://git@github.com/"]
  insteadOf = https://github.com/
```

To test if your auth changes fixed things, attempt to fetch the dependencies with "File" -> "Packages" --> "Reset package caches"

### WatchOS Support
> [!WARNING]
> WatchOS support does not currently include the Embrace Crash Reporter. Instrumentation and observability will be possible but the SDK will not be able to collect crash reports.
>

## Support 

We appreciate any feedback you have on the SDK and the APIs that is provides. To contribute to this project please see our [Contribution Guidelines](https://github.com/embrace-io/embrace-apple-sdk/blob/main/CONTRIBUTING.md) there you'll be able to submit a feature request, create a bug report, or submit a pull request.

For urgent matters (such as outages) or issues concerning the Embrace service or UI reach out in our [Community Slack](https://join.slack.com/t/embraceio-community/shared_invite/zt-ywr4jhzp-DLROX0ndN9a0soHMf6Ksow) for direct, faster assistance.

## License
[![Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-orange)](./LICENSE.txt)

Embrace Apple SDK is published under the Apache-2.0 license. 

[![Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-orange)](./LICENSE.txt)
