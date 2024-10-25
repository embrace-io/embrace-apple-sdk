//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

public extension XCTestCase {
    /// Returns the name of the test running in a swifty manner.
    ///
    /// The `self.name` property of an `XCTestCase` is a `String` showing the name of the class that inherits from `XCTestCase`
    /// and the method being called. That `String` shows all this method in an "objc manner". For example,
    /// if we have the class `MyTest` that inherits from `XCTestCase` and the method `test_doSomething()`
    /// then when that test is being executed the `name` property would be: `-[MyTest test_doSomething].
    ///
    /// This computed property removes the class, and format the method name in more swift manner. So previous example
    /// would end up being `test_doSomething()`.
    var testName: String {
        do {
            var testName = try XCTUnwrap(name.split(separator: " ").last)
            if #available(iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
                let pattern = try Regex("]")
                testName = testName.replacing(pattern, with: "()")
            } else {
                testName.removeLast()
                testName.append(contentsOf: "()")
            }
            return String(testName)
        } catch let exception {
            fatalError("Couldn't create testName: \(exception.localizedDescription)")
        }
    }
}
