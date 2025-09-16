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

### Environment Variables

- `noop`: When set to any value, disables Embrace SDK initialization for baseline performance measurement

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