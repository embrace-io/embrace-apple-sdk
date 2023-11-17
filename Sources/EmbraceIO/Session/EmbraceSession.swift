//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon

/// The Embrace concept of a user session
/// This class handles high level metadata about a session while recording is occuring
/// This class is will be converted to a ``EmbraceStorage.SessionRecord`` struct when
/// it is stored on disk.
public final class EmbraceSession {
    /// A unique identifier for the session
    let id: SessionIdentifier

    /// A device-unique identifier for this process
    let processId: ProcessIdentifier

    /// Used to mark the type of session
    @ThreadSafe
    var state: SessionState

    /// The time at which the session begins
    @ThreadSafe
    var startAt: Date?

    /// The time at which the session ends
    @ThreadSafe
    var endAt: Date?

    /// Used to mark if the session is the first to occur during this process
    @ThreadSafe
    var coldStart: Bool = false

    /// Used to mark the session ended in an expected manner
    @ThreadSafe
    var cleanExit: Bool = false

    /// Used to mark the session that is active when the application was explicitly terminated by the user and/or system
    @ThreadSafe
    var appTerminated: Bool = false

    init(id: SessionIdentifier, state: SessionState, startAt: Date? = nil, endAt: Date? = nil) {
        self.id = id
        self.state = state
        self.processId = ProcessIdentifier.current
        self.startAt = startAt
        self.endAt = endAt
    }
}
