//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Representation of a crash that will be reported through Embrace.
@objc final public class EmbraceCrashReport: NSObject, Sendable {

    /// Unique identifier of this crash.
    public let id: UUID

    /// A string of the actual crash payload collected by `provider`.
    public let payload: String

    /// The unique name of the provider that collected this crash.
    public let provider: String

    /// An internal identifier used by the provider.
    public let internalId: Int?

    /// If available, the session id that was ended by this crash.
    public let sessionId: String?

    /// The date when the crash occurred if available.
    public let timestamp: Date?

    /// If this crash is signal based, the signal that caused the crash.
    public let signal: CrashSignal?

    public init(
        payload: String,
        provider: String,
        internalId: Int? = nil,
        sessionId: String? = nil,
        timestamp: Date? = nil,
        signal: CrashSignal? = nil
    ) {
        self.id = UUID()
        self.payload = payload
        self.provider = provider
        self.internalId = internalId
        self.sessionId = sessionId
        self.timestamp = timestamp
        self.signal = signal
    }
}
