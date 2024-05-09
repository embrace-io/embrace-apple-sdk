//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon

public struct TestConstants {
    public static let domain = "com.test.embrace"
    public static let url = URL(string: "https://embrace.test.com/path")!
    public static let data = "test".data(using: .utf8)!
    public static let date = Date(timeIntervalSince1970: 0)

    public static let sessionId = SessionIdentifier(string: "18EDB6CE-90C2-456B-97CB-91E0F5941CCA")!
    public static let processId = ProcessIdentifier(hex: "12345678")!
    public static let traceId = "traceId"
    public static let spanId = "spanId"

    public static let appId = "appId"
    public static let deviceId = "18EDB6CE90C2456B97CB91E0F5941CCA"
    public static let osVersion = "16.0"
    public static let sdkVersion = "00.1.00"
    public static let appVersion = "1.0"
    public static let userAgent = "Embrace/i/00.1.00"
}
