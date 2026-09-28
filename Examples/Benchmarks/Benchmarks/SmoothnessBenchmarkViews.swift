//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI

/// A long list with non-trivial rows, scrolled by `BenchmarksUITests` to measure hitches with
/// `SmoothnessCaptureService` on vs off.
struct SmoothnessScrollView: View {

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
    }
}

/// A continuously animating screen that keeps the display rendering every frame, so an idle
/// window measures the steady-state CPU cost of the display link and tick handler.
struct SmoothnessAnimationView: View {

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
    }
}
