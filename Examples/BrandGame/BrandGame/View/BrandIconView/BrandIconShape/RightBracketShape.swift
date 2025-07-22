//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI

//
// Converted using https://github.com/quassum/SVG-to-SwiftUI
//
struct RightBracketShape: Shape {

    static let aspectRatio = 300.0 / 215.0

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height

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

        return path
    }
}

#Preview {
    BrandIconShape()
        .aspectRatio(BrandIconShape.aspectRatio, contentMode: .fit)
}
