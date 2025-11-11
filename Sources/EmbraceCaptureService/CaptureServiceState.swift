//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceCommonInternal
#endif
import Foundation

/// The state of a `CaptureService`
@objc public enum CaptureServiceState: Int8, EmbraceAtomicType {
    /// Indicates that the service has not been installed yet.
    case uninstalled

    /// Indicates that the service has been initialized.
    ///
    /// This state can be used to set up necessary dependencies or perform required
    /// modifications (e.g., method swizzling) to enable the service to gather
    /// data when needed.
    ///
    /// - Important: This does not necessarily imply that the service is active.
    case installed

    /// Indicates that the service is active and capturing data.
    case active

    /// Indicates that the service is initialized but is not actively capturing data.
    case paused
}
