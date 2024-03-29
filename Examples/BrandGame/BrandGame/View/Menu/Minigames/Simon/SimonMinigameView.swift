//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI

struct SimonMinigameView: View {
    @State var gameModel = SimonGameModel()

    var body: some View {
        VStack {
            auxillaryView(state: gameModel.gameState, round: gameModel.roundNumber)

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
                gameModel.highlight(icon: icon)
            }
            .onEnded { _ in
                gameModel.select(icon: icon)
            }
    }

    func style(for icon: IconComponent) -> some ShapeStyle {
        if gameModel.gameState == .roundFail {
            return Color.red
        }

        if gameModel.playbackIcon == icon || gameModel.highlightIcon == icon {
            switch icon {
            case .leftBracket: return Color.embraceYellow
            case .leftDot: return Color.embracePink
            case .rightDot: return Color.embraceSteel
            case .rightBracket: return Color.embracePurple
            }
        }
        return Color.primary
    }

    @ViewBuilder
    func auxillaryView(state: SimonGameModel.GameState, round: Int) -> some View {
        switch state {
        case .waitingForStart:
            startButton()
        case .roundPlayback, .roundTestUnderway:
            Text("Round: \(round)")
                .foregroundStyle(Color.embraceYellow)
        case .betweenRounds:
            Text("Success!")
                .foregroundStyle(Color.green)
        case .roundFail:
            Text("Uh-Oh!!!")
                .foregroundStyle(Color.red)
        }

    }

    func startButton() -> some View {
        Button {
            gameModel.start()
        } label: {
            Text("Start")
        }
    }
}

#Preview {
    SimonMinigameView()
}
