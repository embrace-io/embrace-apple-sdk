//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//
    
import Foundation
#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
    import EmbraceConfiguration
    import EmbraceCommonInternal
#endif

class DefaultOtelSignalsLimiter: OTelSignalsLimiter {

    static let emptyType = "__emb.empty__"

    struct MutableState {
        var limits = SessionLimits()

        var customSpanCounter = 0
        var eventCounter: [String: UInt] = [:]
        var linkCounter = 0
        var logCounter: [Int: UInt] = [:]
    }
    var state = EmbraceMutex(MutableState())

    let notificationCenter: NotificationCenter

    init(
        sessionLimits: SessionLimits = SessionLimits(),
        spanEventTypeLimits: SpanEventTypeLimits,
        logSeverityLimits: LogSeverityLimits,
        configNotificationCenter: NotificationCenter
    ) {
        state.withLock {
            $0.limits = sessionLimits
            $0.limits.events.typeLimits = spanEventTypeLimits
            $0.limits.logs.severityLimits = logSeverityLimits
        }
        self.notificationCenter = configNotificationCenter

        notificationCenter.addObserver(
            self,
            selector: #selector(onConfigUpdated),
            name: .embraceConfigUpdated,
            object: nil
        )
    }

    deinit {
        notificationCenter.removeObserver(self)
    }

    @objc func onConfigUpdated(notification: Notification) {
        guard let config = notification.object as? EmbraceConfigurable else {
            return
        }

        state.withLock {
            $0.limits.events.typeLimits = config.spanEventTypeLimits
            $0.limits.logs.severityLimits = config.logSeverityLimits
        }
    }

    func reset() {
        state.withLock {
            $0.customSpanCounter = 0
            $0.eventCounter = [:]
            $0.linkCounter = 0
            $0.logCounter = [:]
        }
    }

    func shouldCreateCustomSpan() -> Bool {
        return state.withLock {
            if $0.customSpanCounter < $0.limits.customSpans.count {
                $0.customSpanCounter += 1
                return true
            }

            return false
        }
    }
    
    func shouldAddSessionEvent(ofType type: EmbraceType?) -> Bool {
        return state.withLock {
            // check total limit
            if $0.eventCounter.count >= $0.limits.events.count {
                return false
            }

            // check limit for event type
            let type = type?.rawValue ?? Self.emptyType

            guard let typeLimits = $0.limits.events.typeLimits,
                  let limit = limitForEventType(type, limits: typeLimits) else {
                return true
            }

            // apply limit
            var result = false

            var count = $0.eventCounter[type] ?? 0
            if count < limit {
                count += 1
                result = true
            }
            $0.eventCounter[type] = count

            return result
        }
    }
    
    func shouldCreateLog(type: EmbraceType, severity: EmbraceLogSeverity) -> Bool {
        // no limits for internal, crash or hang logs
        guard type != .internal &&
              type != .crash &&
              type != .hang else {
            return true
        }

        return state.withLock {
            // check limit for severity type
            let level = consolidatedSeverity(severity)
            let limit = limitForLogSeverity(level, limits: $0.limits.logs.severityLimits)

            // apply limit
            var result = false

            var count = $0.logCounter[level.rawValue] ?? 0
            if count < limit {
                count += 1
                result = true
            }
            $0.logCounter[level.rawValue] = count

            return result
        }
    }
    
    func shouldAddSpanEvent(currentCount count: Int) -> Bool {
        return state.withLock {
            count < $0.limits.customSpans.events.count
        }
    }
    
    func shouldAddSpanLink(currentCount count: Int) -> Bool {
        return state.withLock {
            count < $0.limits.customSpans.links.count
        }
    }
    
    func shouldAddSpanAttribute(currentCount count: Int) -> Bool {
        return state.withLock {
            count < $0.limits.customSpans.attributeCount
        }
    }

    // MARK: Private
    private func limitForEventType(_ type: String, limits: SpanEventTypeLimits) -> UInt? {
        if type == EmbraceType.breadcrumb.rawValue {
            return limits.breadcrumb
        }

        return nil
    }

    private func consolidatedSeverity(_ severity: EmbraceLogSeverity) -> EmbraceLogSeverity {
        switch severity {
        case .warn: return .warn
        case .error, .fatal: return .error
        default: return .info
        }
    }

    private func limitForLogSeverity(_ severity: EmbraceLogSeverity, limits: LogSeverityLimits) -> UInt {
        if severity == .warn {
            return limits.warning
        }

        if severity == .error || severity == .fatal {
            return limits.error
        }

        return limits.info
    }
}
