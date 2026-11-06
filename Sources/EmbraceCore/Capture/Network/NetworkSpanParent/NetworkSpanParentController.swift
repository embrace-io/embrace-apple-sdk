//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceSemantics
#endif

/// Identifies one call that set the network span parent.
///
/// Pass it back to clear that parent. A token stops working once the network span parent
/// is replaced or cleared, so a late clear can never remove a parent set afterwards.
public struct EmbraceNetworkSpanParentToken: Sendable, Hashable {
    let id: UInt64

    /// Returned when a parent couldn't be set. Clearing it does nothing.
    package static let inert = EmbraceNetworkSpanParentToken(id: 0)
}

/// Provides the current network span parent to the network capture.
protocol NetworkSpanParentProvider: AnyObject {
    func currentContext() -> EmbraceSpanContext?
}

/// Holds the process-wide network span parent: the span that new network spans are parented to.
///
/// There is one parent at a time, and setting a new one replaces the previous one. The parent is
/// cleared when the app clears it with its token, when the SDK sees that span end, or when the
/// user session it was set in ends.
///
/// Replacing a parent that is still active is reported as a conflict: a warning naming both
/// spans and, when the replaced parent was set from a span object, a span event on it. Each pair
/// of spans is reported once per user session, and at most
/// `maxReportedConflictsPerUserSession` conflicts are reported per user session. Conflicts
/// beyond that are counted and the count is sent as an internal log when the user session ends.
///
/// All methods are thread safe.
package final class NetworkSpanParentController: NetworkSpanParentProvider {

    static let maxReportedConflictsPerUserSession = 10

    private struct Parent {
        let token: EmbraceNetworkSpanParentToken
        let context: EmbraceSpanContext
        let span: EmbraceSpan?
        let userSessionId: EmbraceIdentifier?

        var description: String {
            if let span {
                return "'\(span.name)'"
            }
            return "span \(context.spanId)"
        }
    }

    private struct Conflict {
        let replaced: Parent
        let replacement: Parent
        let shouldAddEvent: Bool
    }

    private struct ConflictBookkeeping {
        var reportedPairs: Set<String> = []
        var spanIdsWithEvent: Set<String> = []
        var reportedCount = 0
        var droppedCount = 0

        mutating func register(replaced: Parent, replacement: Parent) -> Conflict? {
            let pair = "\(replaced.context.spanId)|\(replacement.context.spanId)"
            guard !reportedPairs.contains(pair) else {
                return nil
            }

            guard reportedCount < NetworkSpanParentController.maxReportedConflictsPerUserSession else {
                droppedCount += 1
                return nil
            }

            reportedPairs.insert(pair)
            reportedCount += 1

            let shouldAddEvent = replaced.span != nil && spanIdsWithEvent.insert(replaced.context.spanId).inserted
            return Conflict(replaced: replaced, replacement: replacement, shouldAddEvent: shouldAddEvent)
        }
    }

    private struct State {
        var parent: Parent?
        var nextTokenId: UInt64 = 1
        var conflicts = ConflictBookkeeping()
        var didWarnInvalidContext = false
    }

    private let state = EmbraceMutex(State())
    private let logger: InternalLogger
    private let currentUserSessionId: () -> EmbraceIdentifier?
    private let notificationCenter: NotificationCenter
    private var userSessionObserver: NSObjectProtocol?

    /// Used to report the number of conflicts that weren't reported individually.
    weak var otel: EmbraceOTelSignalsHandler?

    init(
        logger: InternalLogger,
        notificationCenter: NotificationCenter = .default,
        currentUserSessionId: @escaping () -> EmbraceIdentifier?
    ) {
        self.logger = logger
        self.notificationCenter = notificationCenter
        self.currentUserSessionId = currentUserSessionId

        userSessionObserver = notificationCenter.addObserver(
            forName: .embraceUserSessionDidEnd,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let session = notification.object as? EmbraceUserSession else {
                return
            }
            self?.userSessionDidEnd(id: session.id)
        }
    }

    deinit {
        if let userSessionObserver {
            notificationCenter.removeObserver(userSessionObserver)
        }
    }

    /// Sets the given span as the network span parent.
    /// A span that has already ended is rejected and the previous parent stays.
    package func set(span: EmbraceSpan) -> EmbraceNetworkSpanParentToken {
        guard span.endTime == nil else {
            warnEndedSpan(span)
            return .inert
        }

        return set(context: span.context, span: span)
    }

    /// Sets the span with the given context as the network span parent.
    /// A context whose identifiers can't refer to a span is rejected and the previous parent stays.
    package func set(context: EmbraceSpanContext) -> EmbraceNetworkSpanParentToken {
        return set(context: context, span: nil)
    }

    private func set(context: EmbraceSpanContext, span: EmbraceSpan?) -> EmbraceNetworkSpanParentToken {
        guard context.isValid else {
            let shouldWarn = state.withLock { state -> Bool in
                defer { state.didWarnInvalidContext = true }
                return !state.didWarnInvalidContext
            }

            if shouldWarn {
                logger.warning(
                    "Ignoring invalid network span parent: span id '\(context.spanId)', trace id '\(context.traceId)'. The previous network span parent, if any, stays. Further invalid parents won't be logged."
                )
            }
            return .inert
        }

        let normalizedContext = EmbraceSpanContext(
            spanId: EmbraceSpanContext.normalize(context.spanId),
            traceId: EmbraceSpanContext.normalize(context.traceId)
        )
        let userSessionId = currentUserSessionId()

        let result = state.withLock { state -> (token: EmbraceNetworkSpanParentToken, conflict: Conflict?)? in
            // The span may have ended since it was last checked. A span's end time is recorded
            // before the SDK clears the parent under this lock, so a span that hasn't ended here
            // is cleared when it does, and one that has is never stored.
            if let span, span.endTime != nil {
                return nil
            }

            let token = EmbraceNetworkSpanParentToken(id: state.nextTokenId)
            state.nextTokenId += 1

            let parent = Parent(token: token, context: normalizedContext, span: span, userSessionId: userSessionId)

            // Setting the same span again only issues a new token, it doesn't overlap with anything.
            var conflict: Conflict?
            if let previous = state.parent, previous.context.spanId != parent.context.spanId {
                conflict = state.conflicts.register(replaced: previous, replacement: parent)
            }

            state.parent = parent
            return (token, conflict)
        }

        guard let result else {
            if let span {
                warnEndedSpan(span)
            }
            return .inert
        }

        if let conflict = result.conflict {
            report(conflict)
        }

        return result.token
    }

    private func warnEndedSpan(_ span: EmbraceSpan) {
        logger.warning(
            "Ignoring network span parent '\(span.name)': the span has already ended. The previous network span parent, if any, stays."
        )
    }

    /// Clears the network span parent, if it is still the one set with the given token.
    package func clear(token: EmbraceNetworkSpanParentToken) {
        state.withLock { state in
            if let parent = state.parent, parent.token == token {
                state.parent = nil
            }
        }
    }

    func currentContext() -> EmbraceSpanContext? {
        return state.withLock { $0.parent?.context }
    }

    /// Called for every span the SDK sees end. Clears the network span parent if it is that span.
    func spanDidEnd(spanId: String) {
        // Span ids of spans going through the SDK are always lowercase, like the stored parent's.
        state.withLock { state in
            if state.parent?.context.spanId == spanId {
                state.parent = nil
            }
        }
    }

    /// Clears the network span parent if it was set during the given user session, and reports the
    /// conflicts that weren't reported individually during it.
    func userSessionDidEnd(id: EmbraceIdentifier) {
        let droppedCount = state.withLock { state -> Int in
            // A parent set while no user session was active belongs to the first one that ends.
            if let parent = state.parent, parent.userSessionId == nil || parent.userSessionId == id {
                state.parent = nil
            }

            let droppedCount = state.conflicts.droppedCount
            state.conflicts = ConflictBookkeeping()
            return droppedCount
        }

        guard droppedCount > 0 else {
            return
        }

        try? otel?.internalLog(
            "\(droppedCount) network span parent conflicts weren't reported during the user session.",
            severity: .warn,
            attributes: ["emb.network_span_parent.unreported_conflicts": String(droppedCount)]
        )
    }

    private func report(_ conflict: Conflict) {
        logger.warning(
            "network span parent \(conflict.replaced.description) replaced by \(conflict.replacement.description) while still active"
        )

        guard conflict.shouldAddEvent, let span = conflict.replaced.span else {
            return
        }

        var attributes: EmbraceAttributes = [
            SpanEventSemantics.NetworkSpanParent.keyReplacedBySpanId: conflict.replacement.context.spanId
        ]
        if let name = conflict.replacement.span?.name {
            attributes[SpanEventSemantics.NetworkSpanParent.keyReplacedByName] = name
        }

        span.addEvent(
            name: SpanEventSemantics.NetworkSpanParent.nameReplaced,
            type: nil,
            timestamp: Date(),
            attributes: attributes
        )
    }
}
