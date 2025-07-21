//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import TestSupport
import XCTest

@testable import EmbraceCore

// swiftlint:disable force_cast force_try
class PushNotificationEventTests: XCTestCase {

    let validPayload: [AnyHashable: Any] = [
        PushNotificationEvent.Constants.apsRootKey: [
            PushNotificationEvent.Constants.apsAlert: [
                PushNotificationEvent.Constants.apsTitle: "title",
                PushNotificationEvent.Constants.apsSubtitle: "subtitle",
                PushNotificationEvent.Constants.apsBody: "body"
            ],
            PushNotificationEvent.Constants.apsCategory: "category",
            PushNotificationEvent.Constants.apsBadge: 1
        ]
    ]

    let validLocalizedPayload: [AnyHashable: Any] = [
        PushNotificationEvent.Constants.apsRootKey: [
            PushNotificationEvent.Constants.apsAlert: [
                PushNotificationEvent.Constants.apsTitleLocalized: "title",
                PushNotificationEvent.Constants.apsSubtitleLocalized: "subtitle",
                PushNotificationEvent.Constants.apsBodyLocalized: "body"
            ],
            PushNotificationEvent.Constants.apsCategory: "category",
            PushNotificationEvent.Constants.apsBadge: 1
        ]
    ]

    let validSilentPayload: [AnyHashable: Any] = [
        PushNotificationEvent.Constants.apsRootKey: [
            PushNotificationEvent.Constants.apsContentAvailable: 1
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
        XCTAssertEqual(event.attributes["emb.type"], .string("sys.push_notification"))
        XCTAssertEqual(
            event.attributes["notification.type"],
            .string("notif")
        )
        XCTAssertEqual(event.attributes.count, 2)
    }

    func test_silentPayload() throws {
        // given an event with a valid silent payload with data capture enabled
        let event = try! PushNotificationEvent(userInfo: validSilentPayload, captureData: false)

        // then the attributes are correct
        XCTAssertEqual(event.name, "emb-push-notification")
        XCTAssertEqual(event.attributes["emb.type"], .string("sys.push_notification"))
        XCTAssertEqual(
            event.attributes["notification.type"],
            .string("silent")
        )
        XCTAssertEqual(event.attributes.count, 2)
    }

    func test_validPayload() throws {
        // given an event with a valid payload with data capture disabled
        let event = try! PushNotificationEvent(userInfo: validPayload, captureData: true)

        // then the attributes are correct
        XCTAssertEqual(event.name, "emb-push-notification")
        XCTAssertEqual(event.attributes["emb.type"], .string("sys.push_notification"))
        XCTAssertEqual(
            event.attributes["notification.type"],
            .string("notif")
        )
        XCTAssertEqual(event.attributes["notification.title"], .string("title"))
        XCTAssertEqual(event.attributes["notification.subtitle"], .string("subtitle"))
        XCTAssertEqual(event.attributes["notification.body"], .string("body"))
        XCTAssertEqual(event.attributes["notification.category"], .string("category"))
        XCTAssertEqual(event.attributes["notification.badge"], .int(1))
    }

    func test_validLocalizedPayload() throws {
        // given an event with a valid localized payload with data capture enabled
        let event = try! PushNotificationEvent(userInfo: validLocalizedPayload, captureData: true)

        // then the attributes are correct
        XCTAssertEqual(event.name, "emb-push-notification")
        XCTAssertEqual(event.attributes["emb.type"], .string("sys.push_notification"))
        XCTAssertEqual(
            event.attributes["notification.type"],
            .string("notif")
        )
        XCTAssertEqual(event.attributes["notification.title"], .string("title"))
        XCTAssertEqual(event.attributes["notification.subtitle"], .string("subtitle"))
        XCTAssertEqual(event.attributes["notification.body"], .string("body"))
        XCTAssertEqual(event.attributes["notification.category"], .string("category"))
        XCTAssertEqual(event.attributes["notification.badge"], .int(1))
    }
}

// swiftlint:enable force_cast force_try
