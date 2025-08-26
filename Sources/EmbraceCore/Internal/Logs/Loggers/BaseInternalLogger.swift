//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
    import EmbraceCommonInternal
    import EmbraceStorageInternal
    import EmbraceConfigInternal
    import EmbraceConfiguration
#endif

class BaseInternalLogger: InternalLogger {

    #if DEBUG
        var level: LogLevel = .debug
    #else
        var level: LogLevel = .error
    #endif

    var otel: OTelSignalsHandler?

    struct MutableState {
        var limits: InternalLogLimits = InternalLogLimits()
        var counter: [LogLevel: Int] = [:]
        var currentSession: EmbraceSession?
    }
    private let state = EmbraceMutex(MutableState())

    var limits: InternalLogLimits {
        get { state.withLock { $0.limits } }
        set { state.withLock { $0.limits = newValue } }
    }

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onSessionStart),
            name: .embraceSessionDidStart,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onSessionEnd),
            name: .embraceSessionWillEnd,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func onSessionStart(notification: Notification) {
        state.withLock {
            $0.currentSession = notification.object as? EmbraceSession
            $0.counter.removeAll()
        }
    }

    @objc func onSessionEnd(notification: Notification) {
        state.withLock {
            $0.currentSession = nil
        }
    }

    func output(_ message: String, level: LogLevel, customExport: Bool) {
        print(message)
    }

    @discardableResult func log(
        level: LogLevel,
        message: String,
        attributes: [String: String] = [:],
        customExport: Bool = false
    ) -> Bool {

        if !customExport {
            sendOTelLog(level: level, message: message, attributes: attributes)
        }

        guard self.level != .none && self.level.rawValue <= level.rawValue else {
            return false
        }

        output(message, level: level, customExport: customExport)
        return true
    }

    @discardableResult func trace(_ message: String, attributes: [String: String]) -> Bool {
        return log(level: .trace, message: message, attributes: attributes)
    }
    @discardableResult func trace(_ message: String) -> Bool {
        return log(level: .trace, message: message)
    }

    @discardableResult func debug(_ message: String, attributes: [String: String] = [:]) -> Bool {
        return log(level: .debug, message: message, attributes: attributes)
    }
    @discardableResult func debug(_ message: String) -> Bool {
        return log(level: .debug, message: message)
    }

    @discardableResult func info(_ message: String, attributes: [String: String] = [:]) -> Bool {
        return log(level: .info, message: message, attributes: attributes)
    }
    @discardableResult func info(_ message: String) -> Bool {
        return log(level: .info, message: message)
    }

    @discardableResult func warning(_ message: String, attributes: [String: String] = [:]) -> Bool {
        return log(level: .warning, message: message, attributes: attributes)
    }
    @discardableResult func warning(_ message: String) -> Bool {
        return log(level: .warning, message: message)
    }

    @discardableResult func error(_ message: String, attributes: [String: String] = [:]) -> Bool {
        return log(level: .error, message: message, attributes: attributes)
    }
    @discardableResult func error(_ message: String) -> Bool {
        return log(level: .error, message: message)
    }

    @discardableResult @objc func startup(_ message: String, attributes: [String: String] = [:]) -> Bool {
        return log(level: .info, message: message, attributes: attributes, customExport: true)
    }
    @discardableResult @objc func startup(_ message: String) -> Bool {
        return log(level: .info, message: message, customExport: true)
    }

    @discardableResult @objc func critical(_ message: String, attributes: [String: String] = [:]) -> Bool {
        return log(level: .critical, message: message, attributes: attributes, customExport: true)
    }
    @discardableResult @objc func critical(_ message: String) -> Bool {
        return log(level: .critical, message: message, customExport: true)
    }

    private func sendOTelLog(level: LogLevel, message: String, attributes: [String: String]) {

        let (proceed, currentSession) = state.withLock {
            let limit = $0.limits.limit(for: level)
            guard limit > 0 else {
                return (false, $0.currentSession)
            }

            var count = $0.counter[level] ?? 0
            guard count < limit else {
                return (false, $0.currentSession)
            }

            // update count
            count += 1
            $0.counter[level] = count

            return (true, $0.currentSession)
        }

        guard proceed else {
            return
        }

        // build attributes
        let attributesBuilder = EmbraceLogAttributesBuilder(
            session: currentSession,
            initialAttributes: attributes
        )

        let attributes =
            attributesBuilder
            .addLogType(.internal)
            .addApplicationState()
            .addSessionIdentifier()
            .build()

        // send log
        otel?.log(
            message,
            severity: level.severity,
            type: .internal,
            attributes: attributes
        )
    }
}

extension InternalLogLimits {
    func limit(for level: LogLevel) -> UInt {
        switch level {
        case .trace: return trace
        case .debug: return debug
        case .info: return info
        case .warning: return warning
        case .error: return error

        default: return 0
        }
    }
}
