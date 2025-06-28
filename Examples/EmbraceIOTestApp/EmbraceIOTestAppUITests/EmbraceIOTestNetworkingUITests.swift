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
        app.launch()

        let initButton = app.buttons["EmbraceInitButton"]
        initButton.tap()

        XCTAssertNotNil(initButton.wait(attribute: \.label, is: .equalTo, value: "EmbraceIO has started!", timeout: 5.0))

        let sideMenuButton = app.buttons["SideMenuButton"]
        sideMenuButton.tap()

        app.staticTexts["networking"].tap()

        continueAfterFailure = true
    }

    override func tearDownWithError() throws {

    }

    private var embraceURL: String { "https://embrace.io" }
    private var reqresURL: String { "https://reqres.in" }
    private var reqresUsersAPI: String { "/api/users" }

    private func enterURL(_ url: String) {
        let urlTextField = app.textFields["networkingTests_URLTextField"]
        urlTextField.tap()

        _ = waitUntilElementHasFocus(element: urlTextField)

        urlTextField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (urlTextField.value as? String ?? "").count))

        urlTextField.typeText(url)
        urlTextField.typeText(XCUIKeyboardKey.return.rawValue)
    }

    private func enterAPI(_ api: String) {
        let apiTextField = app.textFields["networkingTests_APITextField"]
        apiTextField.tap()

        _ = waitUntilElementHasFocus(element: apiTextField)

        apiTextField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (apiTextField.value as? String ?? "").count))

        apiTextField.typeText(api)
        apiTextField.typeText(XCUIKeyboardKey.return.rawValue)
    }

    private func selectRequestMethod(_ method: URLRequestMethod) {
        let identifier = method.identifier
        app.buttons[identifier].tap()
    }

    private func enterCustomBodyProperty(key: String, value: String) {
        let bodyKeyTextField = app.textFields["NetworkingTestBody_Key"]
        bodyKeyTextField.tap()

        _ = waitUntilElementHasFocus(element: bodyKeyTextField)

        bodyKeyTextField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (bodyKeyTextField.value as? String ?? "").count))

        bodyKeyTextField.typeText(key)
        bodyKeyTextField.typeText(XCUIKeyboardKey.return.rawValue)

        let bodyValueTextField = app.textFields["NetworkingTestBody_Value"]
        bodyValueTextField.tap()

        _ = waitUntilElementHasFocus(element: bodyValueTextField)

        bodyValueTextField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (bodyValueTextField.value as? String ?? "").count))

        bodyValueTextField.typeText(value)
        bodyValueTextField.typeText(XCUIKeyboardKey.return.rawValue)

        app.buttons["NetworkingTestBody_Insert_Button"].tap()
    }

    private func runNetworkTest() {
        app.buttons["networkCallTestButton"].tap()

        evaluateTestResults(app)
    }

    func testGetRequest() {
        enterURL(embraceURL)
        selectRequestMethod(.get)

        runNetworkTest()
    }

    func testPostRequest() {
        enterURL(reqresURL)
        enterAPI(reqresUsersAPI)
        selectRequestMethod(.post)
        enterCustomBodyProperty(key: "name", value: "Charles")
        enterCustomBodyProperty(key: "job", value: "Whatever")

        runNetworkTest()
    }

    func testPutRequest() {
        enterURL(reqresURL)
        enterAPI("\(reqresUsersAPI)/1234")
        selectRequestMethod(.put)
        enterCustomBodyProperty(key: "name", value: "Charles")
        enterCustomBodyProperty(key: "job", value: "Whatever")

        runNetworkTest()
    }

    func testDeleteRequest() {
        enterURL(reqresURL)
        enterAPI("\(reqresUsersAPI)/1234")
        selectRequestMethod(.delete)

        runNetworkTest()
    }
}
