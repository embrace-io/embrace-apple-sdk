//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

#if COCOAPODS
    import EmbraceIO
#else
    import EmbraceCore
    import EmbraceOTelInternal
#endif

@Observable
class SimonGameModel {

    enum GameState {
        /// user needs to start game
        case waitingForStart

        /// user watching round instructions
        case roundPlayback

        /// user copying round instructions
        case roundTestUnderway

        /// user waiting for next round
        case betweenRounds

        /// user just finished
        case roundFail
    }

    var gameState: GameState = .waitingForStart

    var pattern: [IconComponent] = []

    var roundNumber: Int { pattern.count }

    var gameStateIsPlaying: Bool {
        gameState == .roundPlayback || gameState == .roundTestUnderway || gameState == .betweenRounds
    }

    private(set) var playbackIconIndex: Int?
    private(set) var playbackIcon: IconComponent?
    private(set) var highlightIcon: IconComponent?

    var userPattern: [IconComponent] = []

    /// measures a single game. Parent of multiple round spans (hopefully)
    var gameSpan: Span?

    /// measures a single round. Child of game span
    var roundSpan: Span?

    func start() {
        reset()
        newRound()
        self.gameSpan = buildGameSpan()
    }

    func newRound() {
        userPattern = []

        // add item to `pattern`
        pattern.append(determineNextItem())

        gameState = .roundPlayback
        roundSpan = buildRoundSpan(round: roundNumber)

        // playback pattern to user
        playback()

        // listen for user to copy pattern
    }

    func highlight(icon: IconComponent) {
        highlightIcon = icon
    }

    func select(icon: IconComponent) {
        highlightIcon = nil
        guard gameState == .roundTestUnderway else {
            return
        }

        userPattern.append(icon)
        let patternPrefix = Array(pattern.prefix(userPattern.count))

        // verify round
        if userPattern == patternPrefix {
            if userPattern.count == pattern.count {
                roundSpan?.status = .ok
                roundSpan?.end()
                // NEW ROUND
                gameState = .betweenRounds

                Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { _ in
                    self.newRound()
                }
            }

        } else {
            // fail
            gameState = .roundFail
            roundSpan?.end(errorCode: .failure)
            gameSpan?.setAttribute(key: "round.number", value: .string(String(roundNumber)))
            gameSpan?.end()
            Timer.scheduledTimer(withTimeInterval: 2.4, repeats: false) { _ in
                self.reset()
            }
        }
    }

    private func playback() {
        playbackIconIndex = 0
        playbackIcon = pattern.first

        guard playbackIcon != nil else {
            return
        }

        Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { _ in
            self.playbackIcon = nil
        }

        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            self.playbackIconIndex! += 1
            self.playbackIcon = self.pattern[safe: self.playbackIconIndex!]

            if self.playbackIcon == nil {
                self.gameState = .roundTestUnderway
                timer.invalidate()
            } else {
                Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { _ in
                    self.playbackIcon = nil
                }
            }
        }
    }

    /// reflex icon is randomly picked after removing the initial icon
    private func determineNextItem() -> IconComponent {
        let icons = IconComponent.allCases
        return icons.randomElement()!
    }

    private func pickNextComponent() -> IconComponent {
        return IconComponent.allCases.randomElement()!
    }

    private func reset() {
        highlightIcon = nil
        playbackIcon = nil
        playbackIconIndex = nil
        userPattern = []
        pattern = []

        gameState = .waitingForStart
    }

    private func buildGameSpan() -> Span? {
        guard let embrace = Embrace.client else {
            return nil
        }

        return
            embrace
            .buildSpan(name: "simon-game", type: .ux)
            .startSpan()
    }

    private func buildRoundSpan(round: Int) -> Span? {
        guard let embrace = Embrace.client else {
            return nil
        }

        let builder =
            embrace
            .buildSpan(
                name: "simon-round",
                type: .ux,
                attributes: ["round.number": String(round)]
            )

        if let gameSpan = gameSpan {
            builder.setParent(gameSpan)
        }

        return builder.startSpan()
    }
}

extension Collection {
    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
