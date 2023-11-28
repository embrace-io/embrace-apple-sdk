//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI

struct ReflexMinigameView: View {

    @State var gameModel = ReflexGameModel()

    @GestureState var leftBracketTapped = false

    var messageText: String {
        switch gameModel.gameState {
        case .notStarted: "Touch a Logo Piece"
        case .initialTouched: "Wait for it..."
        case .reflexShown: "Go!"
        case .testComplete: String(format: "Success! %.3fs", gameModel.reflexDuration ?? .nan)
        case .testError: "Wrong one :("
        }
    }

    var body: some View {
        VStack {
            Text(messageText)
                .foregroundStyle(.embraceYellow)

            ZStack {
                LeftBracketShape()
                    .gesture(gesture(for: .leftBracket))
                    .foregroundStyle(style(for: .leftBracket))

                LeftDotShape()
                    .gesture(gesture(for: .leftDot))
                    .foregroundStyle(style(for: .leftDot))

                RightDotShape()
                    .gesture(gesture(for: .rightDot))
                    .foregroundStyle(style(for: .rightDot))

                RightBracketShape()
                    .gesture(gesture(for: .rightBracket))
                    .foregroundStyle(style(for: .rightBracket))
            }
            .aspectRatio(IconShape.aspectRatio, contentMode: .fit)
        }
    }

    func gesture(for icon: IconComponent) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                gameModel.select(icon: icon)
            }
            .onEnded { _ in
                gameModel.dismiss(icon: icon)
            }
    }

    func style(for icon: IconComponent) -> some ShapeStyle {
        if icon == gameModel.initialIcon {
            return Color.embracePink
        } else if icon == gameModel.reflexIcon {
            return Color.embracePurple
        } else {
            return Color.primary
        }
    }

}

#Preview {
    ReflexMinigameView()
      .padding()
}
