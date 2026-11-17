//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCore
    import EmbraceCaptureService
#endif

/// Capture services
extension EmbraceIO {

    /// Adds a capture service after the SDK was started.
    ///
    /// The capture service is installed and started right away. If there's an active session, `onSessionStart()`
    /// is called on it shortly after, on the main queue.
    ///
    /// - Warning: Capture services added through this method **must not use swizzling**.
    ///   By the time the capture service is added the app is already running: the swizzled classes may already be in use,
    ///   other libraries may have swizzled the same methods, and the calls made before the capture service was added are missed.
    ///   This makes swizzling at this point unreliable.
    ///   Capture services that use swizzling must be passed in the options when starting the SDK, which should be done
    ///   as early as possible in the app's lifecycle.
    ///
    /// - Note: The capture service's `onConfigUpdated()`, `onInstall()` and `onStart()` are called while the SDK is locked,
    ///   so they must not start or stop the SDK, nor add capture services.
    /// - Note: This method has no effect if the SDK was stopped, or if a capture service of the same type was already added.
    /// - Parameter captureService: The capture service to add.
    public func add(captureService: CaptureService) {
        Embrace.client?.add(captureService: captureService)
    }
}
