

**Features**

**Updates**

* Adds `MigrationService` in `EmbraceStorage` target to structure DB migrations that occur. Will perform migrations 
during SDK setup if any are outstanding. Converted existing DB schema to be initialized using migrations.



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
