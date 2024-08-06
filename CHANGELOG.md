

**Features**

**Updates**

* Adds `MigrationService` in `EmbraceStorage` target to structure DB migrations that occur. Will perform migrations 
during SDK setup if any are outstanding. Converted existing DB schema to be initialized using migrations.

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
