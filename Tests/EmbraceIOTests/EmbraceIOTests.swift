//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import TestSupport
import XCTest

@testable import EmbraceIO

class EmbraceIOTests: XCTestCase {

    @MainActor
    override func setUp() async throws {
        let _ = EmbraceIO.shared
    }

    func test_attributesStringConversion() {

        let atts: [EmbraceIO.AttributeKey: EmbraceIO.AttributeValueType] = [
            "key1": true,
            "key2": "string",

            "key3": Int(-12),
            "key4": Int8(-12),
            "key5": Int16(-12),
            "key6": Int32(-12),
            "key7": Int64(-12),

            "key8": UInt(12),
            "key9": UInt8(12),
            "key10": UInt16(12),
            "key11": UInt32(12),
            "key12": UInt64(12),

            "key13": Float(12.123),
            "key14": Float32(12.123),
            "key15": Float64(12.123),

            "key16": Double(12.123)
        ]

        let internalsValue: [String: String] = [
            "key1": "true",
            "key2": "string",

            "key3": "-12",
            "key4": "-12",
            "key5": "-12",
            "key6": "-12",
            "key7": "-12",

            "key8": "12",
            "key9": "12",
            "key10": "12",
            "key11": "12",
            "key12": "12",

            "key13": "12.123",
            "key14": "12.123",
            "key15": "12.123",

            "key16": "12.123"
        ]

        let internals = atts.asInternalAttributes()
        XCTAssertEqual(internals, internalsValue)
    }

    func test_dissalowedAttribute() {

        struct NotAllowed: EmbraceIO.AttributeValueType {}

        XCTAssertFalse(isSupportedAttributeValueType(NotAllowed()))
    }

    func test_log() {

        EmbraceIO.shared.log(
            .debug,
            "Hello",
            timestamp: .current,
            attributes: nil
        )

    }

    @concurrent
    func test_concurrentlog() async {

        EmbraceIO.shared.log(
            .debug,
            "Hello",
            timestamp: .current,
            attributes: nil
        )

    }
}
