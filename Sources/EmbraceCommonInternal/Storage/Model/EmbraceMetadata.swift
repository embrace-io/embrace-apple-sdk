//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public enum MetadataRecordType: String, Codable {
    /// Resource that is attached to session and logs data
    case resource

    /// Embrace-generated resource that is deemed required and cannot be removed by the user of the SDK
    case requiredResource

    /// Custom property attached to session and logs data and that can be manipulated by the user of the SDK
    case customProperty

    /// Persona tag attached to session and logs data and that can be manipulated by the user of the SDK
    case personaTag
}

public enum MetadataRecordLifespan: String, Codable {
    /// Value tied to a specific user session. It spans every session part of that user session,
    /// and survives process death for as long as the user session itself does.
    ///
    /// - Note: The raw value is `"session"` and not `"user_session"` on purpose. It is persisted in
    ///         the `lifespanRaw` column, so keeping the original value means records written before
    ///         this case was renamed still decode after an app update. Those older records hold a
    ///         session part id in `lifespanId` instead of a user session id, so no query matches
    ///         them and they get removed as orphans by `cleanMetadata`.
    case userSession = "session"

    /// Value tied to multiple user sessions within a single process
    case process

    /// Value tied to all user sessions until explicitly removed
    case permanent
}

public protocol EmbraceMetadata {
    var key: String { get }
    var value: String { get }
    var typeRaw: String { get }
    var lifespanRaw: String { get }
    var lifespanId: String { get }
    var collectedAt: Date { get }
}

extension EmbraceMetadata {
    public var type: MetadataRecordType? {
        return MetadataRecordType(rawValue: typeRaw)
    }

    public var lifespan: MetadataRecordLifespan? {
        return MetadataRecordLifespan(rawValue: lifespanRaw)
    }
}
