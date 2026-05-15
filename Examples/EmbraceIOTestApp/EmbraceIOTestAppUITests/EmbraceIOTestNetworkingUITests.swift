//
//  EmbraceIOTestNetworkingUITests.swift
//  EmbraceIOTestApp
//
//

import XCTest

@testable import EmbraceIOTestApp

final class EmbraceIOTestNetworkingUITests: XCTestCase {
    var app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = true
        app.launchAndOpenTestTab("networking")
    }

    override func tearDownWithError() throws {

    }

    private var embraceURL: String { "https://embrace.io" }
    private var reqresURL: String { "https://reqres.in" }
    private var reqresUsersAPI: String { "/api/users" }

    private func enterURL(_ url: String) {
        let urlTextField = app.textFields["networkingTests_URLTextField"]
        XCTAssertTrue(urlTextField.waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollUntilHittableElementVisible(urlTextField))
        urlTextField.tap()

        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))

        urlTextField.typeText(
            String(repeating: XCUIKeyboardKey.delete.rawValue, count: (urlTextField.value as? String ?? "").count))

        urlTextField.typeText(url)
        urlTextField.typeText(XCUIKeyboardKey.return.rawValue)
    }

    private func enterAPI(_ api: String) {
        let apiTextField = app.textFields["networkingTests_APITextField"]
        XCTAssertTrue(apiTextField.waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollUntilHittableElementVisible(apiTextField))
        apiTextField.tap()

        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))

        apiTextField.typeText(
            String(repeating: XCUIKeyboardKey.delete.rawValue, count: (apiTextField.value as? String ?? "").count))

        apiTextField.typeText(api)
        apiTextField.typeText(XCUIKeyboardKey.return.rawValue)
    }

    private func selectRequestMethod(_ method: URLRequestMethod) {
        let identifier = method.identifier
        app.buttons[identifier].tap()
    }

    private func enterCustomBodyProperty(key: String, value: String) {
        let bodyKeyTextField = app.textFields["NetworkingTestBody_Key"]
        XCTAssertTrue(bodyKeyTextField.waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollUntilHittableElementVisible(bodyKeyTextField))
        bodyKeyTextField.tap()

        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))

        bodyKeyTextField.typeText(
            String(repeating: XCUIKeyboardKey.delete.rawValue, count: (bodyKeyTextField.value as? String ?? "").count))

        bodyKeyTextField.typeText(key)
        bodyKeyTextField.typeText(XCUIKeyboardKey.return.rawValue)

        let bodyValueTextField = app.textFields["NetworkingTestBody_Value"]
        XCTAssertTrue(bodyValueTextField.waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollUntilHittableElementVisible(bodyValueTextField))
        bodyValueTextField.tap()

        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))

        bodyValueTextField.typeText(
            String(repeating: XCUIKeyboardKey.delete.rawValue, count: (bodyValueTextField.value as? String ?? "").count)
        )

        bodyValueTextField.typeText(value)
        bodyValueTextField.typeText(XCUIKeyboardKey.return.rawValue)

        let button = app.buttons["NetworkingTestBody_Insert_Button"]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollUntilHittableElementVisible(button))
        button.tap()
    }

    private func runNetworkTest() {
        let button = app.buttons["networkCallTestButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollUntilHittableElementVisible(button))
        button.tap()

        evaluateTestResults(app)
    }


    func test_getRequest() {
        enterURL(embraceURL)
        selectRequestMethod(.get)

        runNetworkTest()
    }

    func test_postRequest() {
        enterURL(reqresURL)
        enterAPI(reqresUsersAPI)
        selectRequestMethod(.post)
        enterCustomBodyProperty(key: "name", value: "Charles")
        enterCustomBodyProperty(key: "job", value: "Whatever")

        runNetworkTest()
    }

    func test_putRequest() {
        enterURL(reqresURL)
        enterAPI("\(reqresUsersAPI)/1234")
        selectRequestMethod(.put)
        enterCustomBodyProperty(key: "name", value: "Charles")
        enterCustomBodyProperty(key: "job", value: "Whatever")

        runNetworkTest()
    }

    func test_deleteRequest() {
        enterURL(reqresURL)
        enterAPI("\(reqresUsersAPI)/1234")
        selectRequestMethod(.delete)

        runNetworkTest()
    }
}
