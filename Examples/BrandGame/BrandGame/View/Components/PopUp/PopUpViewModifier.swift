//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI

struct PopUpViewModifier: ViewModifier {
    @Binding private var shouldShow: Bool
    private let text: String

    init(shouldShow: Binding<Bool>, text: String) {
        self._shouldShow = shouldShow
        self.text = text
    }

    func body(content: Content) -> some View {
        content.overlay(
            PopUpView(shouldShow: $shouldShow, text: text),
            alignment: .center
        )
    }
}

extension View {
    func popUp(_ text: String, shouldShow: Binding<Bool>) -> some View {
        self.modifier(
            PopUpViewModifier(
                shouldShow: shouldShow,
                text: text
            )
        )
    }
}
