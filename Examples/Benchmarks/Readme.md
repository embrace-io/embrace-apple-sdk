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

`SmoothnessOverheadUITests` measures what `SmoothnessCaptureService` costs the host app. Each scenario compares `_smoothnessOff` and `_smoothnessOn` arms against the same build, with `HangCaptureService` on in both:

- **testScrolling**: fast swipes through a long list, measured with `XCTOSSignpostMetric.scrollingAndDecelerationMetric` (Apple's own hitch time ratio, independent of the SDK's accounting) and CPU. A `FrameDriver` burns `EMBFrameLoadFraction` (default 0.9) of every frame on the main thread, so the baseline has little headroom and added per-tick cost shows up as hitches.
- **testAnimation**: a 10s window over a screen that animates every frame, measured with CPU and clock time to get steady-state CPU utilization.

XCTest runs test methods alphabetically, and the device drifts over a run: it warms up, may throttle, and background work settles. So each arm runs as two blocks (10 iterations each for scrolling, 3 for animation), numbered so the order is mirrored: `_1_smoothnessOff`, `_2_smoothnessOn`, `_3_smoothnessOnPlusCost`, `_4_smoothnessOnPlusCost`, `_5_smoothnessOn`, `_6_smoothnessOff`. Every arm's average position in the run is the same, so a steady drift cancels out of every comparison. The script merges each arm's blocks, and marks the scenario incomplete if a block is missing. Every iteration also records **Thermal State** (`ProcessInfo.thermalState`, 0 nominal to 3 critical). The report shows each arm's peak, and a run that reaches serious (2) is incomplete, because the device was throttling.

Both screens pin the display to 120Hz, and `Benchmarks-Info.plist` sets `CADisableMinimumFrameDurationOnPhone` so ProMotion iPhones actually run above 60Hz. This applies to the whole app, including the launch benchmarks. A probe display link configured like the SDK's reports two rates. **Display Refresh Rate** is the display's refresh rate, taken from frame durations, so hitches don't lower it. **Display Link Rate** is callbacks per second, which drops when the main thread hitches, so it's context only. The screens also report **Max Display Rate** (`maximumFramesPerSecond`: 120 on ProMotion, 60 otherwise). The SDK's cost is per tick, so a run that fell back to a lower rate (Low Power Mode, a thermal cap) under-measures it. The script marks a scenario incomplete if any arm's average refresh rate is below 85% of the device's maximum (or `EXPECTED_HZ`, if set), or if the arms' averages differ by more than 10%.

Both services disable themselves under a debugger, and running the tests from Xcode attaches one, so both arms set `EMBAllowWatchdogInDebugger=1`. To prove the On arm really measured Smoothness, both scenarios also report **Smoothness Frames**: the frames the SDK counted in the open foreground part. The tests assert it is above 0 in `_smoothnessOn` and 0 in `_smoothnessOff`, and `bin/smoothness_overhead.py` marks the scenario incomplete otherwise.

Each scenario also runs a **positive control**, `_smoothnessOnPlusCost`: the On arm plus 250µs of main-thread work on every frame (`EMBInjectedTickCostMicros`). The script requires every gate in the scenario to report the control as over budget. If a gate misses it, that gate can't see a cost of that size (for example because the baseline is already saturated), so its pass means nothing and the run is incomplete.

In CI, `bin/smoothness_overhead.py` pairs the results and posts a PR comment against the pass criteria: the hitch time ratio delta proven within budget, and less than 1 percentage point of added CPU utilization. The hitch budget is the larger of 5% of the Off mean and 1 ms/s. A scenario passes only if the one-sided 95% Welch upper bound on the On − Off delta is below the budget, and fails if the lower bound is above it. Anything in between is **inconclusive**: the run was too noisy to show the cost is within budget, so it doesn't count as a pass. On PRs the comment only reports. For release sign-off, trigger **On Device Benchmarks** manually: its `strict` input (on by default) sets `STRICT=1`, which fails the job unless every gate passes. A failed, inconclusive, incomplete or missing row, or no results at all, blocks. Use the `device` input to pick the device. Release sign-off needs two strict runs: one on a 120Hz ProMotion device, the worst case for per-tick cost, and one on a 60Hz device, which is most of the installed base.

#### Load calibration

The hitch gate is only sensitive while the Off arm hitches a little. With too little load, added SDK cost disappears into idle headroom, and with too much, frames that already miss can't get much worse. The default 0.9 hasn't been calibrated, and a fraction leaves twice as much free time at 60Hz as at 120Hz. `EMBFrameHeadroomMicros` instead leaves a fixed free time per frame, which stays equally sensitive at both rates, because SDK cost is a fixed number of microseconds per tick.

`SmoothnessLoadCalibrationUITests` sweeps the scroll screen at fractions 0.6, 0.75 and 0.9 and at 1, 2 and 4 ms of headroom, each with Smoothness off and 0, 25 or 250µs injected per frame, at the gate's iteration count. Normal benchmark runs skip it. Run the **Smoothness Load Calibration** workflow manually, once on a 120Hz ProMotion device and once on a 60Hz device. `bin/smoothness_calibration.py` reports, per load:
- the Off hitch ratio;
- each injected cost's delta, its z (the delta in Welch standard errors) and the gate's verdict;
- the refresh rate and peak thermal state.

It suggests the load that best detects the 25µs cost, among loads that ran at the expected rate, weren't throttled and caught the 250µs control. It also suggests an `OFF_HITCH_BAND_<rate>`: half to twice that load's Off hitch ratio. After reviewing them, commit the load as the scroll screen's default, and the band in `run-device-benchmarks.yml`. With a band set, the overhead gate marks a scenario incomplete if its Off hitch ratio falls outside it, which catches the baseline drifting out of the sensitive range (e.g. after an iOS update). Unset, the Off hitch ratio is shown as context only.

For the per-tick cost, launch a debug build with `EMBSmoothnessSignposts=1` and record with the Instruments **os_signpost** instrument (subsystem `io.embrace.sdk`, category `Smoothness`, interval `Tick`). `SmoothnessOverheadTests` in `EmbraceCoreTests` covers the same path as a simulator microbenchmark.

### Environment Variables

- `noop`: When set to any value, disables Embrace SDK initialization for baseline performance measurement
- `EMBHang=1`: Adds `HangCaptureService`
- `EMBSmoothness=1`: Adds `SmoothnessCaptureService`
- `EMBAllowWatchdogInDebugger=1`: Keeps `HangCaptureService` and `SmoothnessCaptureService` running when a debugger is attached
- `EMBInjectedTickCostMicros`: Extra main-thread work, in microseconds, the smoothness screens add to every frame. Used by the positive control
- `EMBFrameHeadroomMicros`: Free time, in microseconds, the scroll screen leaves in every frame. Overrides `EMBFrameLoadFraction`
- `EMBFrameLoadFraction`: Fraction of each frame the scroll screen spends busy on the main thread (default 0.9)
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