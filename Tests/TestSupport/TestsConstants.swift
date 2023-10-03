//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public struct TestConstants {
    public static let shortTimeout: TimeInterval = 0.1
    public static let defaultTimeout: TimeInterval = 1
    public static let longTimeout: TimeInterval = 3
    public static let veryLongTimeout: TimeInterval = 5

    public static let domain = "com.test.embrace"
    public static let url = URL(string: "https://embrace.test.com/path")!
    public static let data = "test".data(using: .utf8)!
}
