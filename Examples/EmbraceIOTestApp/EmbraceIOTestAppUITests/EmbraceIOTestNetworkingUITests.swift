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

        bodyKeyTextField.typeText(
            String(repeating: XCUIKeyboardKey.delete.rawValue, count: (bodyKeyTextField.value as? String ?? "").count))

        bodyKeyTextField.typeText(key)
        bodyKeyTextField.typeText(XCUIKeyboardKey.return.rawValue)

        let bodyValueTextField = app.textFields["NetworkingTestBody_Value"]
        XCTAssertTrue(bodyValueTextField.waitForExistence(timeout: 10))
        XCTAssertTrue(app.scrollUntilHittableElementVisible(bodyValueTextField))
        bodyValueTextField.tap()

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

    func testAllNetworkingCases() {
        castTestGetRequest()
        app.swipeDown()
        castTestPostRequest()
        app.swipeDown()
        castTestPutRequest()
        app.swipeDown()
        castTestDeleteRequest()
    }

    func castTestGetRequest() {
        enterURL(embraceURL)
        selectRequestMethod(.get)

        runNetworkTest()
    }

    func castTestPostRequest() {
        enterURL(reqresURL)
        enterAPI(reqresUsersAPI)
        selectRequestMethod(.post)
        enterCustomBodyProperty(key: "name", value: "Charles")
        enterCustomBodyProperty(key: "job", value: "Whatever")

        runNetworkTest()
    }

    func castTestPutRequest() {
        enterURL(reqresURL)
        enterAPI("\(reqresUsersAPI)/1234")
        selectRequestMethod(.put)
        enterCustomBodyProperty(key: "name", value: "Charles")
        enterCustomBodyProperty(key: "job", value: "Whatever")

        runNetworkTest()
    }

    func castTestDeleteRequest() {
        enterURL(reqresURL)
        enterAPI("\(reqresUsersAPI)/1234")
        selectRequestMethod(.delete)

        runNetworkTest()
    }
}
