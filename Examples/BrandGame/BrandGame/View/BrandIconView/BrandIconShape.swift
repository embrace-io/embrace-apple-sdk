//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI

//
// Converted using https://github.com/quassum/SVG-to-SwiftUI
//
struct BrandIconShape: Shape {

    static let aspectRatio = 300.0 / 215.0

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height

        // Left Bracket
        path.move(to: CGPoint(x: 0.36378 * width, y: 0.20622 * height))
        path.addLine(to: CGPoint(x: 0.36378 * width, y: 0))
        path.addLine(to: CGPoint(x: 0.18189 * width, y: 0))
        path.addLine(to: CGPoint(x: 0.18189 * width, y: 0.00022 * height))
        path.addLine(to: CGPoint(x: 0, y: 0.25005 * height))
        path.addLine(to: CGPoint(x: 0, y: 0.74995 * height))
        path.addLine(to: CGPoint(x: 0.00016 * width, y: 0.74995 * height))
        path.addLine(to: CGPoint(x: 0.18189 * width, y: height))
        path.addLine(to: CGPoint(x: 0.18189 * width, y: 0.99979 * height))
        path.addLine(to: CGPoint(x: 0.36378 * width, y: 0.99979 * height))
        path.addLine(to: CGPoint(x: 0.36378 * width, y: 0.79378 * height))
        path.addLine(to: CGPoint(x: 0.15007 * width, y: 0.79378 * height))
        path.addLine(to: CGPoint(x: 0.15007 * width, y: 0.20622 * height))
        path.addLine(to: CGPoint(x: 0.36378 * width, y: 0.20622 * height))
        path.closeSubpath()

        // Right Bracket
        path.move(to: CGPoint(x: 0.63638 * width, y: 0.20622 * height))
        path.addLine(to: CGPoint(x: 0.63638 * width, y: 0))
        path.addLine(to: CGPoint(x: 0.81811 * width, y: 0))
        path.addLine(to: CGPoint(x: 0.81811 * width, y: 0.00022 * height))
        path.addLine(to: CGPoint(x: width, y: 0.25005 * height))
        path.addLine(to: CGPoint(x: width, y: 0.74995 * height))
        path.addLine(to: CGPoint(x: 0.81811 * width, y: height))
        path.addLine(to: CGPoint(x: 0.81811 * width, y: 0.99979 * height))
        path.addLine(to: CGPoint(x: 0.63638 * width, y: 0.99979 * height))
        path.addLine(to: CGPoint(x: 0.63638 * width, y: 0.79378 * height))
        path.addLine(to: CGPoint(x: 0.8501 * width, y: 0.79378 * height))
        path.addLine(to: CGPoint(x: 0.8501 * width, y: 0.20622 * height))
        path.addLine(to: CGPoint(x: 0.63638 * width, y: 0.20622 * height))
        path.closeSubpath()

        // Right Dot
        path.move(to: CGPoint(x: 0.64593 * width, y: 0.65154 * height))
        path.addCurve(
            to: CGPoint(x: 0.75589 * width, y: 0.50011 * height),
            control1: CGPoint(x: 0.70665 * width, y: 0.65154 * height),
            control2: CGPoint(x: 0.75589 * width, y: 0.58374 * height)
        )
        path.addCurve(
            to: CGPoint(x: 0.64593 * width, y: 0.34868 * height),
            control1: CGPoint(x: 0.75589 * width, y: 0.41647 * height),
            control2: CGPoint(x: 0.70665 * width, y: 0.34868 * height)
        )
        path.addCurve(
            to: CGPoint(x: 0.53597 * width, y: 0.50011 * height),
            control1: CGPoint(x: 0.5852 * width, y: 0.34868 * height),
            control2: CGPoint(x: 0.53597 * width, y: 0.41647 * height)
        )
        path.addCurve(
            to: CGPoint(x: 0.64593 * width, y: 0.65154 * height),
            control1: CGPoint(x: 0.53597 * width, y: 0.58374 * height),
            control2: CGPoint(x: 0.5852 * width, y: 0.65154 * height)
        )
        path.closeSubpath()

        // Left Dot
        path.move(to: CGPoint(x: 0.35423 * width, y: 0.65133 * height))
        path.addCurve(
            to: CGPoint(x: 0.4642 * width, y: 0.49989 * height),
            control1: CGPoint(x: 0.41496 * width, y: 0.65133 * height),
            control2: CGPoint(x: 0.4642 * width, y: 0.58353 * height)
        )
        path.addCurve(
            to: CGPoint(x: 0.35423 * width, y: 0.34846 * height),
            control1: CGPoint(x: 0.4642 * width, y: 0.41626 * height),
            control2: CGPoint(x: 0.41496 * width, y: 0.34846 * height)
        )
        path.addCurve(
            to: CGPoint(x: 0.24427 * width, y: 0.49989 * height),
            control1: CGPoint(x: 0.29351 * width, y: 0.34846 * height),
            control2: CGPoint(x: 0.24427 * width, y: 0.41626 * height)
        )
        path.addCurve(
            to: CGPoint(x: 0.35423 * width, y: 0.65133 * height),
            control1: CGPoint(x: 0.24427 * width, y: 0.58353 * height),
            control2: CGPoint(x: 0.29351 * width, y: 0.65133 * height)
        )
        path.closeSubpath()

        return path
    }
}

#Preview {
    BrandIconShape()
        .aspectRatio(BrandIconShape.aspectRatio, contentMode: .fit)
}
