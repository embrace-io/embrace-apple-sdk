//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Represents an OTel log signal.
public protocol EmbraceLog {

    /// Identifier for the log
    var id: String { get }

    /// Severity of the log
    var severity: EmbraceLogSeverity { get }

    /// Embrace specific type of the log
    var type: EmbraceType { get }

    /// Date when the log was emitted
    var timestamp: Date { get }

    /// Contents of the log
    var body: String { get }

    /// Attributes of the log
    var attributes: [String: String] { get }

    /// Identifier of the active Embrace Session when the log was emitted, if any.
    var sessionId: EmbraceIdentifier? { get }

    /// Identifier of the process when the log was emitted.
    var processId: EmbraceIdentifier { get }
}
