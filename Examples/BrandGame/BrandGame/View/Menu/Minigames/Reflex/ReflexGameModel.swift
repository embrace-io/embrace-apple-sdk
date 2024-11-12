//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCore
import EmbraceOTelInternal
import OpenTelemetryApi
import OpenTelemetrySdk

@Observable
class ReflexGameModel {

    enum GameState: String {

        /// waiting for test to touch the initial component
        case notStarted

        /// user has touched the initial icon and is waiting for the reflex icon component
        case initialTouched

        /// reflex icon has appeared
        case reflexShown

        /// user finished reflex test correctly
        case testComplete

        /// user finished reflex test incorrectly (pushed wrong icon)
        case testError
    }

    private (set) var gameState: GameState = .notStarted

    /// The component the user is touching to start the test
    private (set) var initialIcon: IconComponent?

    /// The component the user needs to touch to finish the test
    private (set) var reflexIcon: IconComponent?

    /// The time the reflexIcon appeared
    private var reflexStartAt: Date?

    /// The time the reflexIcon was pressed
    private var reflexEndAt: Date?

    private var reflexSpan: Span?

    var reflexDuration: TimeInterval? {
        if let startAt = reflexStartAt, let endAt = reflexEndAt {
            return endAt.timeIntervalSince(startAt)
        }
        return nil
    }

    private var reflexShowTimer: Timer?

    private var resetTimer: Timer?

    func select(icon: IconComponent) {
        guard resetTimer == nil else {
            // do not select if game is waiting to be reset
            return
        }

        if initialIcon == nil {
            testBegin(icon: icon)
        } else if icon != initialIcon {
            testSubmit(icon: icon)
        }
    }

    func dismiss(icon: IconComponent) {
        if icon == initialIcon && gameState != .reflexShown {
            reset()
        }
    }

    private func testBegin(icon: IconComponent) {
        guard gameState == .notStarted else {
            return
        }

        initialIcon = icon
        gameState = .initialTouched
        reflexShowTimer = Timer.scheduledTimer(withTimeInterval: .random(in: 2...7), repeats: false) { _ in
            guard self.gameState == .initialTouched else {
                self.reset()
                return
            }

            self.reflexIcon = self.determineReflexIcon()
            let start = Date()
            self.reflexStartAt = start
            self.reflexSpan = self.buildSpan(startTime: start)
            self.gameState = .reflexShown
        }
    }

    private func testSubmit(icon: IconComponent) {
        guard gameState == .reflexShown, let reflexIcon = reflexIcon else {
            reset()
            return
        }

        let endAt = Date()
        reflexEndAt = endAt
        if icon == reflexIcon {
            gameState = .testComplete
            reflexSpan?.end(time: endAt)

        } else {
            gameState = .testError
            reflexSpan?.end(errorCode: .failure, time: endAt)
        }

        resetTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false, block: { [weak self] _ in
            self?.reset()
        })
    }

    /// reflex icon is randomly picked after removing the initial icon
    private func determineReflexIcon() -> IconComponent {
        var icons = IconComponent.allCases
        icons.removeAll { $0 == initialIcon }
        return icons.randomElement()!
    }

    private func reset() {
        initialIcon = nil
        reflexIcon = nil
        reflexStartAt = nil
        reflexEndAt = nil

        reflexShowTimer?.invalidate()
        reflexShowTimer = nil

        resetTimer?.invalidate()
        resetTimer = nil

        reflexSpan = nil

        gameState = .notStarted
    }
}

extension ReflexGameModel {
    private func buildSpan(startTime: Date) -> Span? {
        return Embrace.client?.buildSpan(name: "reflex-measure", type: .ux)
            .setStartTime(time: startTime)
            .startSpan()
    }
}
