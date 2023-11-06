//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// The state of a `Collector`
///  
/// We might want to move this to `EmbraceCommon` as the state is something every
/// single consumer of the `Collector` (and the other protocols that inherit from it)
/// might want to know and use.
///  
/// - Important: if we move this to a `EmbraceCommon` we need to make it `public`
@frozen public enum CollectorState {
    /// Indicates that the collector has been initialized.
    ///
    /// This state can be used to set up necessary dependencies or perform required
    /// modifications (e.g., method swizzling) to enable the collector to gather
    /// data when needed.
    ///
    /// - Important: This does not imply that data collection is currently active.
    case installed

    /// Indicates that the collector has been detached.
    ///
    /// Use this state to ensure all collected data is saved and to
    /// remove any dependencies or resources related to the collector.
    case uninstalled

    /// Indicates that the collector is active and collecting data.
    case listening

    /// Indicates that the collector is initialized but is not actively collecting data.
    case paused
}
