//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Represents an OTel log signal.
public protocol EmbraceLog: EmbraceSignal {
    /// Identifier for the log
    var id: EmbraceIdentifier { get }

    /// Severity of the log
    var severity: EmbraceLogSeverity { get }

    /// Date when the log was emitted
    var timestamp: Date { get }

    /// Contents of the log
    var body: String { get }

    /// Identifier of the active Embrace Session when the log was emitted, if any.
    var sessionId: EmbraceIdentifier? { get }

    /// Identifier of the process when the log was emitted.
    var processId: EmbraceIdentifier { get }
}
