//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceConfigInternal
    import EmbraceConfiguration
    import EmbraceSemantics
#endif

/// Note: Currently we only have 1 type of custom SpanEvent (breadcrumbs)
/// However this class was built in a way that should be easy to add limits for any type of event in the future
class SpanEventsLimiter {

    static let emptyType = "__emb.empty__"

    struct MutableState {
        var counter: [String: UInt] = [:]
        var limits: SpanEventsLimits = SpanEventsLimits()
    }
    var state = EmbraceMutex(MutableState())
    let notificationCenter: NotificationCenter

    init(spanEventsLimits: SpanEventsLimits, configNotificationCenter: NotificationCenter) {
        self.state.withLock {
            $0.limits = spanEventsLimits
        }
        self.notificationCenter = configNotificationCenter

        notificationCenter.addObserver(
            self,
            selector: #selector(onConfigUpdated),
            name: .embraceConfigUpdated,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onSessionStart),
            name: .embraceSessionDidStart,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        notificationCenter.removeObserver(self)
    }

    @objc func onConfigUpdated(notification: Notification) {
        guard let config = notification.object as? EmbraceConfigurable else {
            return
        }

        state.withLock {
            $0.limits = config.spanEventsLimits
        }
    }

    @objc func onSessionStart(notification: Notification) {
        state.withLock {
            $0.counter.removeAll()
        }
    }

    private func limitForEventType(_ type: String, limits: SpanEventsLimits) -> UInt? {
        if type == EmbraceType.breadcrumb.rawValue {
            return limits.breadcrumb
        }

        return nil
    }

    public func shouldAddEvent(event: EmbraceSpanEvent) -> Bool {
        return state.withLock {
            // check limit for event type
            let type = event.type?.rawValue ?? Self.emptyType

            guard let limit = limitForEventType(type, limits: $0.limits) else {
                return true
            }

            // apply limit
            var result = false

            var count = $0.counter[type] ?? 0
            if count < limit {
                count += 1
                result = true
            }
            $0.counter[type] = count

            return result
        }
    }
}
