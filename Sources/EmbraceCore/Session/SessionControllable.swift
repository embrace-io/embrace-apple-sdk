//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
    import EmbraceCommonInternal
    import EmbraceStorageInternal
#endif

/// Protocol for managing sessions.
/// See ``SessionController`` for main conformance
protocol SessionControllable: AnyObject {

    var currentSession: EmbraceSession? { get }
    var currentSessionSpan: EmbraceSpan? { get }

    /// The user session the current part belongs to, or the active snapshot when no part is open.
    /// Owned by ``UserSessionController``; surfaced here so metadata scoping can resolve the active
    /// user session id without taking a second dependency.
    var currentUserSession: EmbraceUserSession? { get }

    /// Whether user-session work is still queued on the storage queue, so `currentUserSession` may not be up to date.
    var hasPendingUserSessionWork: Bool { get }

    /// The current user session's id once every user-session work queued so far has run.
    /// Must not be called on the main thread.
    func currentUserSessionIdAfterPendingWork() -> EmbraceIdentifier?

    /// The user session of the given part, waiting for it if it's still being resolved on the storage queue.
    /// Only the current part and the deferred ones are known: `nil` for any other.
    /// Must not be called on the main thread.
    func userSessionId(ofPart partId: EmbraceIdentifier) -> EmbraceIdentifier?

    @discardableResult
    func startSession(state: SessionState) -> EmbraceSession?

    @discardableResult
    func startSession(state: SessionState, startTime: Date) -> EmbraceSession?

    @discardableResult
    func endSession() -> Date

    /// Ends the current part using the supplied timestamp. Used when splitting a background
    /// part along a user-session cutoff — the part record must close exactly at the cutoff so
    /// the synthetic follow-up part can begin from the same instant.
    @discardableResult
    func endSession(at endTime: Date) -> Date

    func update(state: SessionState)
    func update(appTerminated: Bool)

    var attachmentCount: Int { get }
    func increaseAttachmentCount()

    func clear()
}
