//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI

struct PopUpView: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding private var shouldShow: Bool
    private let text: String

    init(shouldShow: Binding<Bool>, text: String) {
        self._shouldShow = shouldShow
        self.text = text
    }

    var body: some View {
        Group {
            if shouldShow {
                Text(text)
                    .padding()
                    .background(backgroundColor.opacity(0.8))
                    .foregroundColor(foregroundColor)
                    .cornerRadius(10)
                    .transition(.scale.combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                shouldShow = false
                            }
                        }
                    }
            }
        }
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color.embraceYellow : .black
    }

    private var foregroundColor: Color {
        colorScheme == .dark ? .black : Color.white
    }
}

#Preview("Dark Mode", traits: .fixedLayout(width: 200, height: 200)) {
    PopUpView(shouldShow: .constant(true), text: "Yay, it works! ✅")
        .preferredColorScheme(.dark)
}

#Preview("Light Mode", traits: .fixedLayout(width: 200, height: 200)) {
    PopUpView(shouldShow: .constant(true), text: "Yay, it works! ✅")
        .preferredColorScheme(.light)
}
