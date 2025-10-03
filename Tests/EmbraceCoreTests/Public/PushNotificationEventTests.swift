//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

// TODO: Fix

/*
import EmbraceSemantics
import TestSupport
import XCTest

@testable import EmbraceCore

class PushNotificationEventTests: XCTestCase {

    let validPayload: [AnyHashable: Any] = [
        EmbraceOTelSignalsHandler.Constants.apsRootKey: [
            EmbraceOTelSignalsHandler.Constants.apsAlert: [
                EmbraceOTelSignalsHandler.Constants.apsTitle: "title",
                EmbraceOTelSignalsHandler.Constants.apsSubtitle: "subtitle",
                EmbraceOTelSignalsHandler.Constants.apsBody: "body"
            ],
            EmbraceOTelSignalsHandler.Constants.apsCategory: "category",
            EmbraceOTelSignalsHandler.Constants.apsBadge: 1
        ]
    ]

    let validLocalizedPayload: [AnyHashable: Any] = [
        EmbraceOTelSignalsHandler.Constants.apsRootKey: [
            EmbraceOTelSignalsHandler.Constants.apsAlert: [
                EmbraceOTelSignalsHandler.Constants.apsTitleLocalized: "title",
                EmbraceOTelSignalsHandler.Constants.apsSubtitleLocalized: "subtitle",
                EmbraceOTelSignalsHandler.Constants.apsBodyLocalized: "body"
            ],
            EmbraceOTelSignalsHandler.Constants.apsCategory: "category",
            EmbraceOTelSignalsHandler.Constants.apsBadge: 1
        ]
    ]

    let validSilentPayload: [AnyHashable: Any] = [
        EmbraceOTelSignalsHandler.Constants.apsRootKey: [
            EmbraceOTelSignalsHandler.Constants.apsContentAvailable: 1
        ]
    ]

    func test_invalidPayload() throws {
        // when passing an invalid payload
        let expectation = XCTestExpectation()
        XCTAssertThrowsError(try PushNotificationEvent(userInfo: [:])) { error in

            // then it should error out as a PushNotificationError.invalidPayload
            switch error as! PushNotificationError {
            case .invalidPayload:
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_dataCaptureDisabled() throws {
        // given an event with a valid payload with data capture disabled
        let event = try! PushNotificationEvent(userInfo: validPayload, captureData: false)

        // then the attributes are correct
        XCTAssertEqual(event.name, "emb-push-notification")
        XCTAssertEqual(event.attributes["emb.type"], "sys.push_notification")
        XCTAssertEqual(event.attributes["notification.type"], "notif")
        XCTAssertEqual(event.attributes.count, 2)
    }

    func test_silentPayload() throws {
        // given an event with a valid silent payload with data capture enabled
        let event = try! PushNotificationEvent(userInfo: validSilentPayload, captureData: false)

        // then the attributes are correct
        XCTAssertEqual(event.name, "emb-push-notification")
        XCTAssertEqual(event.attributes["emb.type"], "sys.push_notification")
        XCTAssertEqual(event.attributes["notification.type"], "silent")
        XCTAssertEqual(event.attributes.count, 2)
    }

    func test_validPayload() throws {
        // given an event with a valid payload with data capture disabled
        let event = try! PushNotificationEvent(userInfo: validPayload, captureData: true)

        // then the attributes are correct
        XCTAssertEqual(event.name, "emb-push-notification")
        XCTAssertEqual(event.attributes["emb.type"], "sys.push_notification")
        XCTAssertEqual(event.attributes["notification.type"], "notif")
        XCTAssertEqual(event.attributes["notification.title"], "title")
        XCTAssertEqual(event.attributes["notification.subtitle"], "subtitle")
        XCTAssertEqual(event.attributes["notification.body"], "body")
        XCTAssertEqual(event.attributes["notification.category"], "category")
        XCTAssertEqual(event.attributes["notification.badge"], "1")
    }

    func test_validLocalizedPayload() throws {
        // given an event with a valid localized payload with data capture enabled
        let event = try! PushNotificationEvent(userInfo: validLocalizedPayload, captureData: true)

        // then the attributes are correct
        XCTAssertEqual(event.name, "emb-push-notification")
        XCTAssertEqual(event.attributes["emb.type"], "sys.push_notification")
        XCTAssertEqual(event.attributes["notification.type"], "notif")
        XCTAssertEqual(event.attributes["notification.title"], "title")
        XCTAssertEqual(event.attributes["notification.subtitle"], "subtitle")
        XCTAssertEqual(event.attributes["notification.body"], "body")
        XCTAssertEqual(event.attributes["notification.category"], "category")
        XCTAssertEqual(event.attributes["notification.badge"], "1")
    }
}

*/
