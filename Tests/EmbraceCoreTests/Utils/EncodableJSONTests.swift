//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import XCTest

@testable import EmbraceCore

class EncodableJSONTests: XCTestCase {

    struct TestableEncodable: Encodable {
        let json: [String: Any]

        enum CodingKeys: String, CodingKey {
            case json
        }

        init(with dict: [String: Any]) {
            self.json = dict
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(json, forKey: .json)
        }
    }

    func test_encoding() {
        // given a dictionary
        let nestedDict: [String: String] = ["key": "value"]
        let nestedArray: [String] = ["item1", "item2", "item3"]

        let expected: [String: Any] = [
            "string": "String",
            "dictionary": nestedDict,
            "array": nestedArray,
            "bool": true,
            "int": Int(integerLiteral: 0),
            "int8": Int8(integerLiteral: 1),
            "int16": Int16(integerLiteral: 2),
            "int32": Int32(integerLiteral: 3),
            "int64": Int64(integerLiteral: 4),
            "uint": UInt(integerLiteral: 5),
            "uint8": UInt8(integerLiteral: 6),
            "uint16": UInt16(integerLiteral: 7),
            "uint32": UInt32(integerLiteral: 8),
            "uint64": UInt64(integerLiteral: 9),
            "float": Float(floatLiteral: 10),
            "double": Double(floatLiteral: 11),
            "null": NSNull()
        ]

        // when enconding
        let encodable = TestableEncodable(with: expected)
        let data = try! JSONEncoder().encode(encodable)
        let json = try! JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]

        // then the values are correct
        let result = json["json"] as! [String: Any]
        XCTAssertEqual(result["string"] as! String, "String")
        XCTAssertEqual(result["dictionary"] as! [String: String], nestedDict)
        XCTAssertEqual(result["array"] as! [String], nestedArray)
        XCTAssertEqual(result["bool"] as! Bool, true)
        XCTAssertEqual(result["int"] as! Int, 0)
        XCTAssertEqual(result["int8"] as! Int8, 1)
        XCTAssertEqual(result["int16"] as! Int16, 2)
        XCTAssertEqual(result["int32"] as! Int32, 3)
        XCTAssertEqual(result["int64"] as! Int64, 4)
        XCTAssertEqual(result["uint"] as! UInt, 5)
        XCTAssertEqual(result["uint8"] as! UInt8, 6)
        XCTAssertEqual(result["uint16"] as! UInt16, 7)
        XCTAssertEqual(result["uint32"] as! UInt32, 8)
        XCTAssertEqual(result["uint64"] as! UInt64, 9)
        XCTAssertEqual(result["float"] as! Float, 10)
        XCTAssertEqual(result["double"] as! Double, 11)
        XCTAssertEqual(result["null"] as! NSNull, NSNull())
    }
}
