//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// HangLimits manages limits for the app hangs generated through the SDK
public struct HangLimits: Equatable {

    /// Maximum number of captured hangs in a session.
    public let hangPerSession: UInt

    /// Maximum number of samples captures per hang.
    public let samplesPerHang: UInt

    public init(hangPerSession: UInt = 200, samplesPerHang: UInt = 0) {
        self.hangPerSession = hangPerSession
        self.samplesPerHang = samplesPerHang
    }

    public static func == (lhs: HangLimits, rhs: HangLimits) -> Bool {
        return lhs.hangPerSession == rhs.hangPerSession && lhs.samplesPerHang == rhs.samplesPerHang
    }
}
