//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI

struct PointBubble: Identifiable {
    var id: UUID { uuid }
    let uuid = UUID()

    let point: CGPoint
    let color: Color
    let radius = 12.0
}

struct InteractiveBracketLogo: View {

    @State var bubbles: [PointBubble] = []

    var body: some View {
        ZStack(alignment: .center) {
            BrandIconShape()
                .fill(Color.embraceYellow)
                .aspectRatio(BrandIconShape.aspectRatio, contentMode: .fit)
                .overlay(alignment: .topLeading) {
                    ForEach(bubbles) { bubble in
                        Circle()
                            .fill(bubble.color)
                            .position(bubble.point)
                            .frame(width: bubble.radius * 2)
                    }
                }
                .contentShape(BrandIconShape())
                .clipShape(BrandIconShape())
                .onTapGesture { point in
                    bubbles.append(
                        .init(point: point, color: .random)
                    )
                }
        }
    }
}

#Preview {
    InteractiveBracketLogo()
}
