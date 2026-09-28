//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Combine
import QuartzCore
import SwiftUI

/// Pins the display to 120Hz and, optionally, burns a fixed fraction of every frame's budget on the
/// main thread.
///
/// The load keeps each frame close to its deadline, so any per-tick cost the SDK adds turns into
/// measurable hitches instead of disappearing into idle headroom.
///
/// A second, probe display link is configured like the SDK's `FrameTimingSource` (default frame
/// rate range, `.common` mode) and only counts ticks, so `sampleProbeRate()` reports the rate the
/// SDK's own display links actually ran at.
final class FrameDriver: NSObject {

    /// Fraction (0...1) of each frame's duration to spend busy on the main thread.
    private let loadFraction: Double
    private var link: CADisplayLink?
    private var probe: CADisplayLink?
    private var probeTicks = 0
    private var lastSampleTicks = 0
    private var lastSampleTime: CFTimeInterval = 0

    init(loadFraction: Double) {
        self.loadFraction = min(max(loadFraction, 0), 1)
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
        guard loadFraction > 0 else { return }
        let deadline = CACurrentMediaTime() + (link.targetTimestamp - link.timestamp) * loadFraction
        while CACurrentMediaTime() < deadline {}
    }

    @objc private func probeTick(_ link: CADisplayLink) {
        probeTicks += 1
    }
}

/// Shows the probe display link's rate over the last second, for `BenchmarksUITests` to read as the
/// `display-link-rate` static text.
private struct DisplayLinkRateLabel: ViewModifier {

    let driver: FrameDriver
    @State private var rate = "0"
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topTrailing) {
                Text(rate)
                    .font(.caption2.monospacedDigit())
                    .padding(4)
                    .accessibilityIdentifier("display-link-rate")
            }
            .onReceive(timer) { _ in
                rate = String(format: "%.1f", driver.sampleProbeRate())
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
        .modifier(DisplayLinkRateLabel(driver: driver))
        .onAppear { driver.start() }
        .onDisappear { driver.stop() }
    }
}

/// A continuously animating screen that keeps the display rendering every frame, so an idle
/// window measures the steady-state CPU cost of the display link and tick handler. A load-free
/// `FrameDriver` keeps it at 120Hz.
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
        .modifier(DisplayLinkRateLabel(driver: driver))
        .onAppear { driver.start() }
        .onDisappear { driver.stop() }
    }
}
