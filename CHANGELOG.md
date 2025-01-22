## 6.7.1
*Jan 22nd, 2025**
* Fixes
    * Fixed an issue that caused the crash `'Cannot form weak reference to instance X of class Y'`.
	* Fixed an issue that prevented enabling/disabling certain functionalities.
	* Fixed incompatibility issues with AppLovin.

## 6.7.0
*Jan 10th, 2025**
* Features
    * Improvements to the Automatic View Capture functionality, allowing attributes to be added to traces (`TTFR` and `TTI`) using the `addAttributesToTrace(_:)` method.
* Fixes
    * Fixed an issue causing crashes in views controllers with very short lifecycles (particularly in hosting controllers acting as internal bridges in SwiftUI).
    * Fixed a bug causing compilation issues related to the use of `DispatchQueue`.

## 6.6.0
*Dec 12th, 2024*
* Features
    * Added new instrumentation for the `ViewCaptureService`. Can be enabled through `ViewCaptureService.Options.instrumentFirstRender`.
    * Added url blacklist for the `URLSessionCaptureService`. Can be configured through `URLSessionCaptureService.Options.ignoredURLs`.
    * Added the ability to auto terminate spans if the session ends while the span is still open.
    * Updated the OpenTelemetry dependency to v1.12.1 which fixes some concurrency related crashes.
    * Improved logic around Embrace data uploads and retries.
    * Deprecated `Span.markAsKeySpan()`.
* Fixes
    * Fixed the remote config parse sometimes failing.
    * Fixed the remote config cache not working properly.
    * Fixed crash logs sometimes not containing the session properties.
    * Fixed keychain related crash/hang during startup.
    * Fixed issues with the `WebViewCaptureService` that could lead to a crash.
    * Fixed issue with the `URLSessionCaptureService` when dealing with `URLSessionDelegate` objects in Objective-C responding to methods without conforming to specific protocols.

## 6.5.2
*Nov 14th, 2024*
* Features
    * `EmbraceCrashReporter` now receives a list of signals to be ignored. `SIGTERM` is ignored by default now.
* Fixes
    * Fixed network payload capture rules not working.
    * Fixed `WebViewCaptureService` preventing the web view delegate from receiving messages.
    * Fixed `PushNotificationCaptureService` preventing the user notification delegate from receiving messages.
    * Fixed log batching logic.

## 6.5.1
*Oct 29th, 2024*
* Features
    * Improved performance during the startup of the SDK.
* Fixes
    * Fixed compilation errors in WatchOS.
    * Fixed visibility of `LogLevel`.

## 6.5.0
*Oct 18th, 2024*
* Features
    * Removed `SwiftLint` from `Package.swift` as a dependency, which reduces the download size of our SDK and prevents dependency resolution conflicts.
    * For those consuming the SDK without an `appId`, `Embrace.Options` now includes the possibility to provide custom configuration (implementing `EmbraceConfigurable`).
* Fixes
    * Fixed a linking conflict issue affecting some users both with SPM and CocoaPods.
    * Implemented a fix to expose user customization methods (`userName`, `userEmail`, `userIdentifier`, and `clearUserProperties`) to Objective-C.
    * Fixed a bug that caused the `Span.Status` to be incorrect when exporting a session ended due to a crash.

## 6.4.2
*Oct 2nd, 2024*
* Fixes
    * Fixed crash in `URLSessionCaptureService`.
    * Fixed network body capture logs not being exported.
    * Fixed logic for background sessions.
    * Fixed linker error on simulators in iOS 17.5 and below when using cocoapods.

## 6.4.1
*Sep 26th, 2024*
* Features
    * Updated OpenTelemetry dependencies to v1.10.1.
* Fixes
    * Fixed logs not having resources from the session when being recovered during the SDK startup.
    * Fixed crash with the `gtm-session-fetcher` library.
    * Fixed KSCrash dependency compilation issues in Xcode 16.

## 6.4.0
*Sep 13th, 2024*
* Features
    * Added the option to use the SDK without an `appId` using `Embrace.Options`.
    * Introduced a new parameter in the `log` API: `stackTraceBehavior` to specify the behavior for automatically capturing stack traces within a log.
    * Added the capability to securely capture the body of network requests.
* Changes
    * Removed `-dynamic` targets from Swift Package Manager.
    * Discontinued capturing the screen resolution of devices.
* Fixes
    * Updated `GRDB` to the current latest version (`6.29.1`) to support Xcode 16.
    * Addressed issues related to our service for capturing Network Requests with the new concurrency system (aka. `async` / `await`).
    * Fixed a crash associated with being with another player proxying `URLSession`.
    * Resolved an issue that prevented proper forwarding of calls to the original delegate when swizzling `URLSession` due to a retention issue.
    * Corrected the public API `recordCompletedSpan` to set `Span.Status` consistently with other `end` methods.

## 6.3.0
*Aug 7th, 2024*
* Features
    * Added new public target: `EmbraceSemantics` to expose constants and attributes used to extend OTel Semantic Conventions
    * Added Cocoapods support
    * Added logic to link an emitted `LogRecord` to the active span context
    * Created new APIs for `W3C.traceparent` to be used to support manually instrumented network requests
* Changes
    * Update `Embrace` to expose `LogType` on the `log` method
    * Renamed `LogType.default` to `LogType.message`
    * Adds `MigrationService` in `EmbraceStorage` target to structure DB migrations that occur. Will perform migrations
during SDK setup if any are outstanding. Converted existing DB schema to be initialized using migrations.
* Fixes
    * Fixed the public `addPersona(persona: String, lifespan: MetadataLifespan)` method which wasn't properly forwarding the `lifespan`
    * Fixed a bug that caused a reentrancy issue with the database when persisting spans.

## 6.2.0

July 30th, 2024

**Features**

* Adds `PushNotificationCaptureService` to instrument notifications received using Apple's `UserNotifications` framework
* Adds `Embrace.lastRunEndState` method to retrieve an indication of how the previous start of the SDK finished
    * Provided values can be `unavailable, `crash`, and `cleanExit`
* Adds `CaptureServiceBuilder` to provide easier interface to setup/configure `CaptureService` instances
* Adds `Embrace.tracer(instrumentationName: String)` method to retrieve OpenTelemetry `Tracer`
    * This is useful for manual instrumentation using the `OpenTelemetryApi` directly
* Adds ability to set "User Personas" in the `MetadataHandler`
    * User Personas are great ways to tag users and identify commonalities
    * See `MetadataHandler+Personas` for interface definition

** Changes **
* Updates `TapCaptureService` with options to better control data capture
    * Allows you to ignore specific views by class, or to prevent coordinate capture
    * Optional `TapCaptureServiceDelegate` to have fine grained control over tap capture

** Fixes **
* Fixes bug that prevented user properties from being included on an Embrace session
* Cleanup of public interface and code level documentation

## 6.1.1

**Bug fixes**
* Bumps version in EmbraceMeta.swift

## 6.1.0

July 3rd, 2024

**Features**

* Updates license to Apache 2.0
* Adds `flush(_ span: Span)` method to manually write span data to disk
* Adds `WebViewCaptureService` to instrument `WKWebView` interactions
* Adds `EmbraceCrashlyticsSupport` target to read Crashlytics crash reports
* Adds "Internal Log" functionality to allow for logs to be created to observe SDK behavior/health
    * Will have attribute `emb.type = sys.internal` to differentiate from user logs (`emb.type = sys.log`)

** Changes **
* Updates upload of spans to the `v2/spans` endpoint
* Adds migration functionality to `EmbraceStorage` target
    * Updates SpanRecord table with `process_identifier` to better help Span recovery and recording of spans
    during SDK setup
* Creates CODE_OF_CONDUCT.md

**Bug fixes**
* Fixes `URLSessionDelegateProxy` behavior when calling `URLSessionDelegate` methods
  * Issue occurred when deciding when to call `task.delegate` vs. `session.delegate`


## 6.0.0

April 22nd, 2024

**Features**

* Initial release of the 6.0.0 SDK.
* This major version introduces a new core architecture focusing on:
  * [OpenTelemetry](https://github.com/open-telemetry/opentelemetry-swift) Tracing and Logging at its core.
  * Persistence in SQLite using [GRDB](https://github.com/groue/GRDB.swift)
  * Swift-first interface for developers of Apple platforms
* Automatic Instrumentation of:
  * Application Crash Reports
  * Network Requests
  * Device Low Power Mode
  * Application Memory Warnings
  * UIViewController appearance
  * User Tap Gestures
* Manual instrumentation using:
  * Spans for Performance Tracing
  * Log messages
  * Breadcrumbs
* Allows for generic export of Traces and Logs via the protocols in the [OpenTelemetrySdk](https://github.com/open-telemetry/opentelemetry-swift).
* Allows for custom Automatic Instrumentation via `CaptureService` subclasses
