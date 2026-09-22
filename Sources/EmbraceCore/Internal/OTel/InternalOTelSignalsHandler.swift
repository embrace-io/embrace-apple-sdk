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
    /// Forwards an already-built log to the OTel pipeline, without saving it to storage
    /// nor adding it to the upload batch.
    ///
    /// The log is exported verbatim. None of the session-scoped attributes that regular logs
    /// get are derived here, because the caller is expected to have built them already: these
    /// logs can belong to a session and a process other than the current ones, and re-deriving
    /// the attributes would describe the wrong session.
    func exportLog(_ log: EmbraceLog)
}
