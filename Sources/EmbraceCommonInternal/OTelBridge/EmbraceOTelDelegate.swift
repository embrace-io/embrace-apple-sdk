//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

/// Protocol used to receive signals emitted from 3rd party OTel implementations
public protocol EmbraceOTelDelegate {

    /// Called when a span is started
    func onStartSpan(_ span: EmbraceSpan)

    /// Called when a span is ended
    func onEndSpan(_ span: EmbraceSpan)

    /// Called when a new log is emitted
    func onEmitLog(_ log: EmbraceLog)
}
