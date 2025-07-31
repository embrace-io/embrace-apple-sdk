//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI

//
// Converted using https://github.com/quassum/SVG-to-SwiftUI
//
struct LeftDotShape: Shape {

    static let aspectRatio = 300.0 / 215.0

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height

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
