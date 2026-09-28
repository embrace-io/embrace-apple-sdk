//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import QuartzCore
import SwiftUI

/// Pins the display to 120Hz and, optionally, burns a fixed fraction of every frame's budget on the
/// main thread.
///
/// The load keeps each frame close to its deadline, so any per-tick cost the SDK adds turns into
/// measurable hitches instead of disappearing into idle headroom.
final class FrameDriver: NSObject {

    /// Fraction (0...1) of each frame's duration to spend busy on the main thread.
    private let loadFraction: Double
    private var link: CADisplayLink?

    init(loadFraction: Double) {
        self.loadFraction = min(max(loadFraction, 0), 1)
    }

    func start() {
        guard link == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 80, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    /// Must be called to release the driver, since `CADisplayLink` retains its target.
    func stop() {
        link?.invalidate()
        link = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        guard loadFraction > 0 else { return }
        let deadline = CACurrentMediaTime() + (link.targetTimestamp - link.timestamp) * loadFraction
        while CACurrentMediaTime() < deadline {}
    }
}

/// A long list with non-trivial rows, scrolled by `BenchmarksUITests` to measure hitches with
/// `SmoothnessCaptureService` on vs off.
///
/// Runs a `FrameDriver` at `EMBFrameLoadFraction` (default 0.75) of every frame, so the baseline
/// is a screen with little headroom left rather than one that never hitches.
struct SmoothnessScrollView: View {

    @State private var driver = FrameDriver(
        loadFraction: Double(ProcessInfo.processInfo.environment["EMBFrameLoadFraction"] ?? "") ?? 0.75
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
        .onAppear { driver.start() }
        .onDisappear { driver.stop() }
    }
}
