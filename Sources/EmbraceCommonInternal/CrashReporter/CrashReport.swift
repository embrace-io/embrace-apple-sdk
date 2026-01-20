//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Representation of a crash that will be reported through Embrace.
@objc public class EmbraceCrashReport: NSObject {

    /// Unique identifier of this crash.
    public private(set) var id: UUID

    /// A string of the actual crash payload collected by `provider`.
    public private(set) var payload: String

    /// The unique name of the provider that collected this crash.
    public private(set) var provider: String

    #if os(watchOS)
        /// An internal identifier used by the provider.
        public private(set) var internalId: Int64?
    #else
        /// An internal identifier used by the provider.
        public private(set) var internalId: Int?
    #endif

    /// If available, the session id that was ended by this crash.
    public private(set) var sessionId: String?

    /// The date when the crash occurred if available.
    public private(set) var timestamp: Date?

    /// If this crash is signal based, the signal that caused the crash.
    public private(set) var signal: CrashSignal?

    #if os(watchOS)
        public init(
            payload: String,
            provider: String,
            internalId: Int64? = nil,
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
    #else
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
    #endif
}
