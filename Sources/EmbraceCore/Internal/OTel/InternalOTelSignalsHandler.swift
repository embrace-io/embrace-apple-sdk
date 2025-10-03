//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceSemantics
#endif

typealias InternalOTelSignalsHandler = EmbraceOTelSignalsHandler & AutoTerminationSpansHandler & OnlyExportableLogsHandler

protocol AutoTerminationSpansHandler {
    func autoTerminateSpans()
}

protocol OnlyExportableLogsHandler {
    func exportLog(
        _ message: String,
        severity: EmbraceLogSeverity,
        type: EmbraceType,
        timestamp: Date,
        attributes: [String: String]
    )
}
