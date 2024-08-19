//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal

// swiftlint:disable line_length

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

    public static let rsaPublicKey = "MIIBCgKCAQEAor8onPvG/tF2PJyYJISMXzKX/IW3jvpYveLKCiufySKiytzl6diKJmeMDD8RzrFWMyyxqJSOxnftF4stiAhmkmHKf0+YSqQ44/hGbd5uGCSziUGM6Ai6eoCcaiepDmOpaCXCnjpE4qaNHJSEtt5LxqmLojWjtIvCiGNMiVueQKjk29WOXvWXDLWUV1UTJRc7zQq/grSLK4lGD2rzyuR+bMvqStATgF1XU3UfW7iYZDcfir+m21rgoOGQZm+dY38rDeUOTTC2drswJE0K8a+7S+AB0rjjXHQIJjM8QaroaehNQC+zlzXkS2TKD2QPP+Qmpkw7hPYIOKZSV5XurDLfcQIDAQAB"
}

// swiftlint:enable line_length
