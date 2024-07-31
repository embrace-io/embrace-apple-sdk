//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI

struct PillText<S: ShapeStyle>: View {
    let text: String
    let selected: Bool
    let cornerSize: CGSize
    let style: S

    init(
        _ text: String,
        selected: Bool = false,
        style: S = Color.primary,
        cornerSize: CGSize = .init(width: 24.0, height: 24.0)
    ) {

        self.text = text
        self.selected = selected
        self.cornerSize = cornerSize
        self.style = style
    }

    var body: some View {
        Text(text)
            .padding(.horizontal, cornerSize.width / 2)
            .padding(.vertical, cornerSize.height / 4)
            .background( style.opacity(selected ? 1 : 0))
            .clipShape(RoundedRectangle(cornerSize: cornerSize))
            .overlay(
                RoundedRectangle(cornerSize: cornerSize)
                    .stroke(style, lineWidth: 2)
            ) // Border
    }
}

#Preview("Unselected") {
    PillText("Text", selected: false, style: Color.embracePink)
}

#Preview("Selected") {
    PillText("Text", selected: true, style: Color.embracePink)
}
