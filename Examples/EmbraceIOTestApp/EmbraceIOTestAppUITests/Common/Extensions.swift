//
//  Extensions.swift
//  EmbraceIOTestApp
//
//

import XCTest

extension NSPredicate {
    static func keyPath<T, U>(
        _ keyPath: KeyPath<T, U>,
        is type: NSComparisonPredicate.Operator = .equalTo,
        value: U,
        modifier: NSComparisonPredicate.Modifier = .direct,
        options: NSComparisonPredicate.Options = []
    ) -> NSPredicate {

        return NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: keyPath),
            rightExpression: NSExpression(forConstantValue: value),
            modifier: modifier,
            type: type,
            options: options
        )
    }
}

extension XCUIElement {
    var hasFocus: Bool { value(forKey: "hasKeyboardFocus") as? Bool ?? false }

    func wait<U>(
        attribute keyPath: KeyPath<XCUIElement, U>,
        is comparisonOperator: NSComparisonPredicate.Operator,
        value: U,
        timeout: TimeInterval = 10
    ) -> XCUIElement? {

        let predicate = NSPredicate.keyPath(
            keyPath,
            is: comparisonOperator,
            value: value
        )

        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed ? self : nil
    }
}

extension XCTestCase {
    func waitUntilElementHasFocus(
        element: XCUIElement, timeout: TimeInterval = 600, file: StaticString = #file, line: UInt = #line
    ) -> XCUIElement {
        let expectation = expectation(description: "waiting for element \(element) to have focus")

        let timer = Timer(timeInterval: 1, repeats: true) { timer in
            guard element.hasFocus else { return }

            expectation.fulfill()
            timer.invalidate()
        }

        RunLoop.current.add(timer, forMode: .common)

        wait(for: [expectation], timeout: timeout)

        return element
    }

    func waitUntilElementIsEnabled(element: XCUIElement, timeout: TimeInterval = 600, file: StaticString = #file, line: UInt = #line) -> XCUIElement {
        let expectation = expectation(description: "waiting for element \(element) to be enabled")

        let timer = Timer(timeInterval: 1, repeats: true) { timer in
            guard element.isEnabled else { return }

            expectation.fulfill()
            timer.invalidate()
        }

        RunLoop.current.add(timer, forMode: .common)

        wait(for: [expectation], timeout: timeout)

        return element
    }

    func evaluateTestResults(_ app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts["TEST RESULT:"].waitForExistence(timeout: 60))
        XCTAssertTrue(app.staticTexts["PASS"].exists)
        XCTAssertFalse(app.staticTexts["FAIL"].exists)
    }
}

extension XCUIApplication {
    func launchAndOpenTestTab(_ testTabName: String, coldStart: Bool = false) {
        self.launchEnvironment["UITestMode"] = "YES"
        self.launchEnvironment["DisableAnimations"] = "YES"
        self.launch()

        if coldStart {
            let coldButton = self.buttons["EmbraceInitForceState_Cold"]
            XCTAssertTrue(coldButton.waitForExistence(timeout: 10))
            coldButton.tap()
        }

        let initButton = self.buttons["EmbraceInitButton"]
        XCTAssertTrue(initButton.waitForExistence(timeout: 10))
        initButton.tap()

        XCTAssertNotNil(
            initButton.wait(attribute: \.label, is: .equalTo, value: "EmbraceIO has started!", timeout: 10.0))

        let sideMenuButton = self.buttons["SideMenuButton"]
        XCTAssertTrue(sideMenuButton.waitForExistence(timeout: 10))
        sideMenuButton.tap()

        let testScreenButton = self.staticTexts[testTabName]
        XCTAssertTrue(testScreenButton.waitForExistence(timeout: 10))
        testScreenButton.tap()
    }

    func scrollUntilHittableElementVisible(_ element: XCUIElement) -> Bool {
        guard element.exists else { return false }

        var scrollCount = 0
        while !element.isHittable {
            self.swipeUp()
            scrollCount += 1
            if scrollCount >= 10 {
                return false
            }
        }

        return true
    }
}
