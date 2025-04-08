//
//  Extensions.swift
//  EmbraceIOTestApp
//
//

import XCTest

extension XCUIElement {
    var hasFocus: Bool { value(forKey: "hasKeyboardFocus") as? Bool ?? false }
}

extension XCTestCase {
    func waitUntilElementHasFocus(element: XCUIElement, timeout: TimeInterval = 600, file: StaticString = #file, line: UInt = #line) -> XCUIElement {
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
}
