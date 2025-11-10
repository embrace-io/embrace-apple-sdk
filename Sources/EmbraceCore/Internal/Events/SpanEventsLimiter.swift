//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceConfigInternal
    import EmbraceConfiguration
    import EmbraceOTelInternal
    import EmbraceSemantics
#endif

/// Note: Currently we only have 1 type of custom SpanEvent (breadcrumbs)
/// However this class was built in a way that should be easy to add limits for any type of event in the future
class SpanEventsLimiter {
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

    #if DEBUG
        private let _unlimitedBreadcrumbs: Bool = ProcessInfo.processInfo.environment["EMBIgnoreBreadcrumbLimits"] == "1"
    #else
        private let _unlimitedBreadcrumbs: Bool = false
    #endif
    private func limitForEventType(_ type: String?, limits: SpanEventsLimits) -> UInt? {
        if type == SpanEventType.breadcrumb.rawValue {
            if _unlimitedBreadcrumbs {
                return UInt.max
            }
            return limits.breadcrumb
        }

        return nil
    }

    public func applyLimits(events: [SpanEvent]) -> [SpanEvent] {
        return state.withLock {
            var result: [SpanEvent] = []

            for event in events {
                // check limit for event type
                guard let eventType = event.attributes[SpanEventSemantics.keyEmbraceType]?.description,
                    let limit = limitForEventType(eventType, limits: $0.limits)
                else {
                    result.append(event)
                    continue
                }

                // apply limit
                var count = $0.counter[eventType] ?? 0
                if count < limit {
                    result.append(event)
                    count += 1
                }
                $0.counter[eventType] = count
            }

            return result
        }
    }
}
