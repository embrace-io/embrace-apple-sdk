//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// The state of a `CaptureService`
///  
/// We might want to move this to `EmbraceCommon` as the state is something every
/// single consumer of the `CaptureService` (and the other protocols that inherit from it)
/// might want to know and use.
///  
/// - Important: if we move this to a `EmbraceCommon` we need to make it `public`
@frozen public enum CaptureServiceState {
    /// Indicates that the service has been initialized.
    ///
    /// This state can be used to set up necessary dependencies or perform required
    /// modifications (e.g., method swizzling) to enable the service to gather
    /// data when needed.
    ///
    /// - Important: This does not necessarily imply that the service is active.
    case installed

    /// Indicates that the service has been detached.
    ///
    /// Use this state to ensure all captured data is saved and to
    /// remove any dependencies or resources related to the service.
    case uninstalled

    /// Indicates that the service is active and capturing data.
    case listening

    /// Indicates that the service is initialized but is not actively capturing data.
    case paused
}
