//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import Foundation

// swiftlint:disable line_length

public struct TestConstants {
    public static let domain = "com.test.embrace"
    public static let url = URL(string: "https://embrace.test.com/path")!
    public static let data = "test".data(using: .utf8)!
    public static let date = Date(timeIntervalSince1970: 0)

    public static let sessionId = SessionIdentifier(string: "18EDB6CE-90C2-456B-97CB-91E0F5941CCA")!
    public static let processId = ProcessIdentifier(string: "12345678")
    public static let traceId = "traceId"
    public static let spanId = "spanId"

    public static let appId = "appId"
    public static let deviceId = DeviceIdentifier(string: "18EDB6CE90C2456B97CB91E0F5941CCA")!
    public static let osVersion = "16.0"
    public static let sdkVersion = "00.1.00"
    public static let appVersion = "1.0"
    public static let userAgent = "Embrace/i/00.1.00"

    public static let rsaPublicKey =
        """
        -----BEGIN PUBLIC KEY-----
        MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAn1Mbg+uF2GAZ2BZvFzKE
        2gyE6cQOESpWTAuzXp0u9jCMJO+/LcKv6d3oaP/vZRDTtGPAfxYgc0tBiAYdOtkl
        hiNQvb4puA34ai7h3jbBWsZgA0P5UtYflhR79CCXHH/1SuzaX4G6YYDdfQKYxAF/
        vLNpi7q8LMt8iSGCFxsMyKs+gfMPqUQVy0At7LjGnrBMV50SRu0lCslbtb+LSb1v
        F5EEpmw3d8M58dZkPUwgN9XU/nbfQt2X1tPg8SvZGLBxZHqVzaIQLCZr9O/XUq33
        /TsOrZSTNdw/K6bs6nBzYnagbcoeHBVWYT8l1xvHE3b1Rnc3r5MCTaLUM7Tqb7an
        qwIDAQAB
        -----END PUBLIC KEY-----
        """
    public static let rsaSanitizedPublicKey =
        "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAn1Mbg+uF2GAZ2BZvFzKE2gyE6cQOESpWTAuzXp0u9jCMJO+/LcKv6d3oaP/vZRDTtGPAfxYgc0tBiAYdOtklhiNQvb4puA34ai7h3jbBWsZgA0P5UtYflhR79CCXHH/1SuzaX4G6YYDdfQKYxAF/vLNpi7q8LMt8iSGCFxsMyKs+gfMPqUQVy0At7LjGnrBMV50SRu0lCslbtb+LSb1vF5EEpmw3d8M58dZkPUwgN9XU/nbfQt2X1tPg8SvZGLBxZHqVzaIQLCZr9O/XUq33/TsOrZSTNdw/K6bs6nBzYnagbcoeHBVWYT8l1xvHE3b1Rnc3r5MCTaLUM7Tqb7anqwIDAQAB"
}

// swiftlint:enable line_length
