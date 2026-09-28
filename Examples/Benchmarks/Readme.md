# Embrace SDK Benchmarks

This project contains performance benchmarks for the Embrace Apple SDK to measure its impact on app launch time and other performance metrics.

## Overview

The benchmark app is a minimal iOS application that allows testing the performance impact of the Embrace SDK initialization. It includes both UI tests and unit tests to measure various performance metrics.

## Structure

- **Benchmarks/**: Main iOS app with Embrace SDK integration
- **BenchmarksTests/**: Unit tests for benchmarking
- **BenchmarksUITests/**: UI tests for measuring app launch performance

## Key Tests

### Launch Performance Tests

The project includes two main launch performance tests:

1. **testLaunchPerformance()**: Measures app launch time with Embrace SDK enabled
2. **testLaunchPerformanceNoop()**: Measures app launch time with Embrace SDK disabled (no-op mode)

These tests use `XCTApplicationLaunchMetric()` to accurately measure the time it takes for the app to launch.

## Running the Benchmarks

### Prerequisites

- Xcode 15.0 or later
- iOS 16.0 or later target device/simulator

### Running Tests

1. Open `Benchmarks.xcworkspace` in Xcode
2. Select the target device or simulator
3. Run the UI tests to measure launch performance:
   ```
    + U (or Product > Test)
   ```

### Smoothness Overhead Tests (release gate)

`SmoothnessOverheadUITests` measures what `SmoothnessCaptureService` costs the host app. Each scenario runs twice against the same build, as `_smoothnessOff` and `_smoothnessOn`, with `HangCaptureService` on in both:

- **testScrolling**: fast swipes through a long list, measured with `XCTOSSignpostMetric.scrollingAndDecelerationMetric` (Apple's own hitch time ratio, independent of the SDK's accounting) and CPU. A `FrameDriver` burns `EMBFrameLoadFraction` (default 0.75) of every frame on the main thread, so the baseline has little headroom and added per-tick cost shows up as hitches.
- **testAnimation**: a 10s window over a screen that animates every frame, measured with CPU and clock time to get steady-state CPU utilization.

Both screens pin the display to 120Hz, and `Benchmarks-Info.plist` sets `CADisableMinimumFrameDurationOnPhone` so ProMotion iPhones actually run above 60Hz. This applies to the whole app, including the launch benchmarks.

In CI, `bin/smoothness_overhead.py` pairs the results and posts a PR comment against the pass criteria: no significant hitch time ratio regression (≥5% and ≥1 ms/s, α = 0.05), and less than 1 percentage point of added CPU utilization. The comment doesn't fail the job, because release sign-off is manual. To run on another device (e.g. a 60Hz model), trigger **On Device Benchmarks** manually with the `device` input.

For the per-tick cost, launch a debug build with `EMBSmoothnessSignposts=1` and record with the Instruments **os_signpost** instrument (subsystem `io.embrace.sdk`, category `Smoothness`, interval `Tick`). `SmoothnessOverheadTests` in `EmbraceCoreTests` covers the same path as a simulator microbenchmark.

### Environment Variables

- `noop`: When set to any value, disables Embrace SDK initialization for baseline performance measurement
- `EMBHang=1`: Adds `HangCaptureService`
- `EMBSmoothness=1`: Adds `SmoothnessCaptureService`
- `EMBFrameLoadFraction`: Fraction of each frame the scroll screen spends busy on the main thread (default 0.75)
- `EMBBenchmarkScreen`: Launches into `smoothness-scroll` or `smoothness-animation` instead of the default screen
- `EMBSmoothnessSignposts=1`: Debug builds only. Wraps each Smoothness tick in an `os_signpost` interval

## Interpreting Results

The benchmark tests will output performance metrics showing:
- App launch time with Embrace SDK enabled
- App launch time with Embrace SDK disabled (baseline)
- The performance impact (difference) of the Embrace SDK

This data helps ensure the Embrace SDK maintains minimal performance overhead while providing comprehensive observability features.

## CI Integration

This benchmark project is integrated with the CI/CD pipeline to automatically detect performance regressions in pull requests.

### Automated Performance Testing

The benchmarks run automatically in CI through the `run_perf.yml` GitHub workflow action, which:

1. Executes the benchmark tests using `bin/benchmark`
2. Compares performance metrics against the main branch
3. Reports any significant performance regressions in the PR

This ensures that changes to the Embrace SDK don't introduce unacceptable performance overhead before they're merged.

### Performance Comparison Script

The `bin/perfcomp.py` script is used to analyze and compare benchmark results between different branches or commits, helping identify performance trends and regressions.

## Configuration

The app is configured with a test app ID (`"bench"`) for benchmarking purposes. In production usage, you would replace this with your actual Embrace app ID.