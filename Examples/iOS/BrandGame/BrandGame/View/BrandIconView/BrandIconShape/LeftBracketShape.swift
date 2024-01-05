//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI

struct LeftBracketShape: Shape {

    static let aspectRatio = 300.0/215.0

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height

        // Left Bracket
        path.move(to: CGPoint(x: 0.36378*width, y: 0.20622*height))
        path.addLine(to: CGPoint(x: 0.36378*width, y: 0))
        path.addLine(to: CGPoint(x: 0.18189*width, y: 0))
        path.addLine(to: CGPoint(x: 0.18189*width, y: 0.00022*height))
        path.addLine(to: CGPoint(x: 0, y: 0.25005*height))
        path.addLine(to: CGPoint(x: 0, y: 0.74995*height))
        path.addLine(to: CGPoint(x: 0.00016*width, y: 0.74995*height))
        path.addLine(to: CGPoint(x: 0.18189*width, y: height))
        path.addLine(to: CGPoint(x: 0.18189*width, y: 0.99979*height))
        path.addLine(to: CGPoint(x: 0.36378*width, y: 0.99979*height))
        path.addLine(to: CGPoint(x: 0.36378*width, y: 0.79378*height))
        path.addLine(to: CGPoint(x: 0.15007*width, y: 0.79378*height))
        path.addLine(to: CGPoint(x: 0.15007*width, y: 0.20622*height))
        path.addLine(to: CGPoint(x: 0.36378*width, y: 0.20622*height))
        path.closeSubpath()

        return path
    }
}

#Preview {
    BrandIconShape()
        .aspectRatio(BrandIconShape.aspectRatio, contentMode: .fit)
}
