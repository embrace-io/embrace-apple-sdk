//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//
    
import Foundation
#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

typealias InternalOTelSignalsHandler = OTelSignalsHandler & AutoTerminationSpanHandler

protocol AutoTerminationSpanHandler {
    func autoTerminateSpans()
}
