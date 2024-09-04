//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// This protocol is used to add configuration to the runtime of the SDK
/// It is used to configure the ongoing behavior of the SDK
@objc public protocol EmbraceConfigurable {
    var isSDKEnabled: Bool { get }

    var isBackgroundSessionEnabled: Bool { get }

    var isNetworkSpansForwardingEnabled: Bool { get }

    var internalLogLimits: InternalLogLimits { get }

    var networkPayloadCaptureRules: [NetworkPayloadCaptureRule] { get }

    /// Tell the configurable implementation it should update if possible.
    func update()
}
