//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public protocol EmbraceSpanExporter {

    /// Export the collection of Spans
    @discardableResult func export(spans: [SpanData]) -> SpanExporterResultCode

    /// Exports the collection of  Spans that have not yet been exported.
    @discardableResult func flush() -> SpanExporterResultCode

    /// Called when TracerSdkFactory.shutdown()} is called, if this SpanExporter is registered
    ///  to a TracerSdkFactory object.
    func shutdown()
}

/// The possible results for the export method.
public enum SpanExporterResultCode {
    /// The export operation finished successfully.
    case success

    /// The export operation finished with an error.
    case failure

    /// Merges the current result code with other result code
    /// - Parameter newResultCode: the result code to merge with
    mutating func mergeResultCode(newResultCode: SpanExporterResultCode) {
        // If both results are success then return success.
        if self == .success && newResultCode == .success {
            self = .success
            return
        }
        self = .failure
    }
}
