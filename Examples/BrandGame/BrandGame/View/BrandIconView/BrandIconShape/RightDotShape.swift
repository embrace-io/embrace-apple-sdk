//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI

//
// Converted using https://github.com/quassum/SVG-to-SwiftUI
//
struct RightDotShape: Shape {

    static let aspectRatio = 300.0/215.0

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height

        // Right Dot
        path.move(to: CGPoint(x: 0.64593*width, y: 0.65154*height))
        path.addCurve(
            to: CGPoint(x: 0.75589*width, y: 0.50011*height),
            control1: CGPoint(x: 0.70665*width, y: 0.65154*height),
            control2: CGPoint(x: 0.75589*width, y: 0.58374*height)
        )

        path.addCurve(
            to: CGPoint(x: 0.64593*width, y: 0.34868*height),
            control1: CGPoint(x: 0.75589*width, y: 0.41647*height),
            control2: CGPoint(x: 0.70665*width, y: 0.34868*height)
        )

        path.addCurve(
            to: CGPoint(x: 0.53597*width, y: 0.50011*height),
            control1: CGPoint(x: 0.5852*width, y: 0.34868*height),
            control2: CGPoint(x: 0.53597*width, y: 0.41647*height)
        )

        path.addCurve(
            to: CGPoint(x: 0.64593*width, y: 0.65154*height),
            control1: CGPoint(x: 0.53597*width, y: 0.58374*height),
            control2: CGPoint(x: 0.5852*width, y: 0.65154*height)
        )

        path.closeSubpath()

        return path
    }
}

#Preview {
    BrandIconShape()
        .aspectRatio(BrandIconShape.aspectRatio, contentMode: .fit)
}
