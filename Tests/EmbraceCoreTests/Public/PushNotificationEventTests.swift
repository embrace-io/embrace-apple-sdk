//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

@testable import EmbraceCore
import XCTest
import TestSupport

// swiftlint:disable force_cast force_try
class PushNotificationEventTests: XCTestCase {

    let validPayload: [AnyHashable: Any] = [
        PushNotificationEvent.Constants.rootKey: [
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
        PushNotificationEvent.Constants.rootKey: [
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
        PushNotificationEvent.Constants.rootKey: [
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
        XCTAssertEqual(event.name, PushNotificationEvent.Constants.eventName)
        XCTAssertEqual(event.attributes["emb.type"], .string(PushNotificationEvent.Constants.eventType))
        XCTAssertEqual(
            event.attributes[PushNotificationEvent.Constants.keyType],
            .string(PushNotificationEvent.Constants.notificationType)
        )
        XCTAssertEqual(event.attributes.count, 2)
    }

    func test_silentPayload() throws {
        // given an event with a valid silent payload with data capture enabled
        let event = try! PushNotificationEvent(userInfo: validSilentPayload, captureData: false)

        // then the attributes are correct
        XCTAssertEqual(event.name, PushNotificationEvent.Constants.eventName)
        XCTAssertEqual(event.attributes["emb.type"], .string(PushNotificationEvent.Constants.eventType))
        XCTAssertEqual(
            event.attributes[PushNotificationEvent.Constants.keyType],
            .string(PushNotificationEvent.Constants.silentType)
        )
        XCTAssertEqual(event.attributes.count, 2)
    }

    func test_validPayload() throws {
        // given an event with a valid payload with data capture disabled
        let event = try! PushNotificationEvent(userInfo: validPayload, captureData: true)

        // then the attributes are correct
        XCTAssertEqual(event.name, PushNotificationEvent.Constants.eventName)
        XCTAssertEqual(event.attributes["emb.type"], .string(PushNotificationEvent.Constants.eventType))
        XCTAssertEqual(
            event.attributes[PushNotificationEvent.Constants.keyType],
            .string(PushNotificationEvent.Constants.notificationType)
        )
        XCTAssertEqual(event.attributes[PushNotificationEvent.Constants.keyTitle], .string("title"))
        XCTAssertEqual(event.attributes[PushNotificationEvent.Constants.keySubtitle], .string("subtitle"))
        XCTAssertEqual(event.attributes[PushNotificationEvent.Constants.keyBody], .string("body"))
        XCTAssertEqual(event.attributes[PushNotificationEvent.Constants.keyCategory], .string("category"))
        XCTAssertEqual(event.attributes[PushNotificationEvent.Constants.keyBadge], .int(1))
    }

    func test_validLocalizedPayload() throws {
        // given an event with a valid localized payload with data capture enabled
        let event = try! PushNotificationEvent(userInfo: validLocalizedPayload, captureData: true)

        // then the attributes are correct
        XCTAssertEqual(event.name, PushNotificationEvent.Constants.eventName)
        XCTAssertEqual(event.attributes["emb.type"], .string(PushNotificationEvent.Constants.eventType))
        XCTAssertEqual(
            event.attributes[PushNotificationEvent.Constants.keyType],
            .string(PushNotificationEvent.Constants.notificationType)
        )
        XCTAssertEqual(event.attributes[PushNotificationEvent.Constants.keyTitle], .string("title"))
        XCTAssertEqual(event.attributes[PushNotificationEvent.Constants.keySubtitle], .string("subtitle"))
        XCTAssertEqual(event.attributes[PushNotificationEvent.Constants.keyBody], .string("body"))
        XCTAssertEqual(event.attributes[PushNotificationEvent.Constants.keyCategory], .string("category"))
        XCTAssertEqual(event.attributes[PushNotificationEvent.Constants.keyBadge], .int(1))
    }
}

// swiftlint:enable force_cast force_try
