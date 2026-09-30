//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Combine
@_spi(Private) import EmbraceCore
import QuartzCore
import SwiftUI

/// The `SmoothnessCaptureService` the app started with, or `nil` if `EMBSmoothness` wasn't set.
enum SmoothnessProbe {
    static var service: SmoothnessCaptureService?

    /// Frames the SDK has counted in the open foreground part. `0` means Smoothness isn't
    /// running, e.g. because it disabled itself under a debugger.
    static var frameCount: Int {
        service?.openPartFrameCount ?? 0
    }
}

/// Pins the display to 120Hz and, optionally, burns a fixed fraction of every frame's budget on the
/// main thread.
///
/// The load keeps each frame close to its deadline, so any per-tick cost the SDK adds turns into
/// measurable hitches instead of disappearing into idle headroom.
///
/// It can also inject a fixed cost into every tick (`EMBInjectedTickCostMicros`), standing in for
/// SDK per-tick work of a known size. `SmoothnessOverheadUITests` uses it as a positive control:
/// the overhead gate must catch it, or the gate can't see a cost of that size.
///
/// A second, probe display link is configured like the SDK's `FrameTimingSource` (default frame
/// rate range, `.common` mode) and only counts ticks, so `sampleProbeRate()` reports the rate the
/// SDK's own display links actually ran at.
final class FrameDriver: NSObject {

    /// Fraction (0...1) of each frame's duration to spend busy on the main thread.
    private let loadFraction: Double
    /// Extra fixed time, in seconds, to spend busy on the main thread every tick.
    private let injectedCost: CFTimeInterval
    private var link: CADisplayLink?
    private var probe: CADisplayLink?
    private var probeTicks = 0
    private var lastSampleTicks = 0
    private var lastSampleTime: CFTimeInterval = 0

    init(loadFraction: Double, injectedCost: CFTimeInterval = FrameDriver.injectedCostFromEnvironment) {
        self.loadFraction = min(max(loadFraction, 0), 1)
        self.injectedCost = max(injectedCost, 0)
    }

    /// `EMBInjectedTickCostMicros` in seconds, or `0` if unset.
    static var injectedCostFromEnvironment: CFTimeInterval {
        (Double(ProcessInfo.processInfo.environment["EMBInjectedTickCostMicros"] ?? "") ?? 0) / 1_000_000
    }

    func start() {
        guard link == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 80, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        self.link = link

        let probe = CADisplayLink(target: self, selector: #selector(probeTick(_:)))
        probe.add(to: .main, forMode: .common)
        self.probe = probe
    }

    /// Must be called to release the driver, since `CADisplayLink` retains its target.
    func stop() {
        link?.invalidate()
        link = nil
        probe?.invalidate()
        probe = nil
    }

    /// Probe ticks per second since the previous call, or `0` on the first call.
    func sampleProbeRate() -> Double {
        let now = CACurrentMediaTime()
        defer {
            lastSampleTicks = probeTicks
            lastSampleTime = now
        }
        guard lastSampleTime > 0, now > lastSampleTime else { return 0 }
        return Double(probeTicks - lastSampleTicks) / (now - lastSampleTime)
    }

    @objc private func tick(_ link: CADisplayLink) {
        guard loadFraction > 0 || injectedCost > 0 else { return }
        let deadline = CACurrentMediaTime() + (link.targetTimestamp - link.timestamp) * loadFraction + injectedCost
        while CACurrentMediaTime() < deadline {}
    }

    @objc private func probeTick(_ link: CADisplayLink) {
        probeTicks += 1
    }
}

/// Shows, once a second, the values `BenchmarksUITests` reads back as static texts:
/// - `display-link-rate`: the probe display link's rate over the last second.
/// - `smoothness-frames`: `SmoothnessProbe.frameCount`, which proves whether the SDK is active.
private struct ProbeLabels: ViewModifier {

    let driver: FrameDriver
    @State private var rate = "0"
    @State private var smoothnessFrames = "0"
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topTrailing) {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(rate)
                        .accessibilityIdentifier("display-link-rate")
                    Text(smoothnessFrames)
                        .accessibilityIdentifier("smoothness-frames")
                }
                .font(.caption2.monospacedDigit())
                .padding(4)
            }
            .onReceive(timer) { _ in
                rate = String(format: "%.1f", driver.sampleProbeRate())
                smoothnessFrames = String(SmoothnessProbe.frameCount)
            }
    }
}

/// A long list with non-trivial rows, scrolled by `BenchmarksUITests` to measure hitches with
/// `SmoothnessCaptureService` on vs off.
///
/// Runs a `FrameDriver` at `EMBFrameLoadFraction` (default 0.9) of every frame, so the baseline
/// is a screen with little headroom left rather than one that never hitches.
struct SmoothnessScrollView: View {

    @State private var driver = FrameDriver(
        loadFraction: Double(ProcessInfo.processInfo.environment["EMBFrameLoadFraction"] ?? "") ?? 0.9
    )

    var body: some View {
        List(0..<2_000, id: \.self) { index in
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(hue: Double(index % 36) / 36, saturation: 0.6, brightness: 0.9))
                    .frame(width: 44, height: 44)
                    .overlay(Text("\(index % 100)").font(.caption.bold()).foregroundStyle(.white))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Row \(index)")
                        .font(.headline)
                    Text("Smoothness overhead benchmark row with a secondary line of text")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 4)
        }
        .accessibilityIdentifier("smoothness-list")
        .modifier(ProbeLabels(driver: driver))
        .onAppear { driver.start() }
        .onDisappear { driver.stop() }
    }
}

/// A continuously animating screen that keeps the display rendering every frame, so an idle
/// window measures the steady-state CPU cost of the display link and tick handler. A load-free
/// `FrameDriver` keeps it at 120Hz, and adds only the injected cost, if any.
struct SmoothnessAnimationView: View {

    @State private var driver = FrameDriver(loadFraction: 0)

    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            Canvas { canvas, size in
                for index in 0..<24 {
                    let angle = time * 1.5 + Double(index) * .pi / 12
                    let radius = min(size.width, size.height) * 0.35
                    let point = CGPoint(
                        x: size.width / 2 + cos(angle) * radius,
                        y: size.height / 2 + sin(angle * 1.3) * radius
                    )
                    let rect = CGRect(x: point.x - 10, y: point.y - 10, width: 20, height: 20)
                    canvas.fill(Path(ellipseIn: rect), with: .color(Color(hue: Double(index) / 24, saturation: 0.7, brightness: 0.9)))
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityIdentifier("smoothness-animation")
        .modifier(ProbeLabels(driver: driver))
        .onAppear { driver.start() }
        .onDisappear { driver.stop() }
    }
}
