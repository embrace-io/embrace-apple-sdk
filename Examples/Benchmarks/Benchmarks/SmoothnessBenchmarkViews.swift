//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Combine
@_spi(Private) import EmbraceCore
import QuartzCore
import SwiftUI
import UIKit

/// The `SmoothnessCaptureService` the app started with, or `nil` if `EMBSmoothness` wasn't set.
enum SmoothnessProbe {
    static var service: SmoothnessCaptureService?

    /// Frames the SDK has counted in the open foreground part. `0` means Smoothness isn't
    /// running, e.g. because it disabled itself under a debugger.
    static var frameCount: Int {
        service?.openPartFrameCount ?? 0
    }
}

/// Pins the display to 120Hz and burns `loadFraction` of every frame on the main thread, so any
/// per-tick SDK cost shows up as hitches instead of disappearing into idle time.
///
/// `injectedCost` (`EMBInjectedTickCostMicros`) adds a fixed cost per tick, the positive control
/// in `SmoothnessOverheadUITests`.
///
/// A probe display link, configured like the SDK's `FrameTimingSource`, measures the refresh rate.
final class FrameDriver: NSObject {

    /// Fraction (0...1) of each frame's duration to spend busy on the main thread.
    private let loadFraction: Double
    /// Extra fixed time, in seconds, to spend busy on the main thread every tick.
    private let injectedCost: CFTimeInterval
    private var link: CADisplayLink?
    private var probe: CADisplayLink?
    private var probeFrameDurations: [CFTimeInterval] = []

    init(
        loadFraction: Double,
        injectedCost: CFTimeInterval = FrameDriver.injectedCostFromEnvironment
    ) {
        self.loadFraction = min(max(loadFraction, 0), 1)
        self.injectedCost = max(injectedCost, 0)
    }

    /// The scroll screen's load: `EMBFrameLoadFraction` (default 0.9).
    static func scrollLoadFromEnvironment() -> FrameDriver {
        FrameDriver(loadFraction: Double(ProcessInfo.processInfo.environment["EMBFrameLoadFraction"] ?? "") ?? 0.9)
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

    /// The display's refresh rate since the previous call, from the median frame duration, or `0`
    /// if no tick arrived.
    func sampleRefreshRate() -> Double {
        defer { probeFrameDurations.removeAll(keepingCapacity: true) }
        let durations = probeFrameDurations.filter { $0 > 0 }.sorted()
        guard !durations.isEmpty else { return 0 }
        return 1 / durations[durations.count / 2]
    }

    @objc private func tick(_ link: CADisplayLink) {
        guard loadFraction > 0 || injectedCost > 0 else { return }
        let load = (link.targetTimestamp - link.timestamp) * loadFraction
        let deadline = CACurrentMediaTime() + load + injectedCost
        while CACurrentMediaTime() < deadline {}
    }

    @objc private func probeTick(_ link: CADisplayLink) {
        probeFrameDurations.append(link.targetTimestamp - link.timestamp)
    }
}

/// Shows, once a second, the values `SmoothnessOverheadUITests` reads back as static texts:
/// - `display-refresh-rate`: the display's refresh rate over the last second.
/// - `max-display-rate`: the screen's `maximumFramesPerSecond` (120 on ProMotion, 60 otherwise).
/// - `smoothness-frames`: `SmoothnessProbe.frameCount`, which proves whether the SDK is active.
/// - `thermal-state`: `ProcessInfo.thermalState` as its raw value (0 nominal ... 3 critical).
private struct ProbeLabels: ViewModifier {

    let driver: FrameDriver
    @State private var refreshRate = "0"
    @State private var maxRate = "0"
    @State private var smoothnessFrames = "0"
    @State private var thermalState = String(ProcessInfo.processInfo.thermalState.rawValue)
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topTrailing) {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(refreshRate)
                        .accessibilityIdentifier("display-refresh-rate")
                    Text(maxRate)
                        .accessibilityIdentifier("max-display-rate")
                    Text(smoothnessFrames)
                        .accessibilityIdentifier("smoothness-frames")
                    Text(thermalState)
                        .accessibilityIdentifier("thermal-state")
                }
                .font(.caption2.monospacedDigit())
                .padding(4)
            }
            .onReceive(timer) { _ in
                refreshRate = String(format: "%.1f", driver.sampleRefreshRate())
                maxRate = String(Self.maximumFramesPerSecond)
                smoothnessFrames = String(SmoothnessProbe.frameCount)
                thermalState = String(ProcessInfo.processInfo.thermalState.rawValue)
            }
    }

    private static var maximumFramesPerSecond: Int {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first?.screen.maximumFramesPerSecond ?? 0
    }
}

/// A long list with non-trivial rows, scrolled by `SmoothnessOverheadUITests` to measure hitches with
/// `SmoothnessCaptureService` on vs off.
///
/// Runs a `FrameDriver` at `EMBFrameLoadFraction` (default 0.9).
struct SmoothnessScrollView: View {

    @State private var driver = FrameDriver.scrollLoadFromEnvironment()

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

/// Animates every frame, so an idle window measures the steady-state CPU cost of the SDK's tick
/// handler. Its `FrameDriver` adds no load, only the injected cost, if any.
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
