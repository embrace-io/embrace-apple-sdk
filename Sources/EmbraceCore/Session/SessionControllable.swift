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
