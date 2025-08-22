//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceOTelInternal
    import EmbraceStorageInternal
    import EmbraceSemantics
    import EmbraceConfiguration
#endif

class StorageEmbraceLogExporter: LogRecordExporter {

    @ThreadSafe
    private(set) var state: State
    private let logBatcher: LogBatcher
    private let validation: LogDataValidation

    private let counter = EmbraceMutex([LogLevel: Int]())

    enum State {
        case active
        case inactive
    }

    init(logBatcher: LogBatcher, state: State = .active, validators: [LogDataValidator] = .default) {
        self.state = state
        self.logBatcher = logBatcher
        self.validation = LogDataValidation(validators: validators)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onSessionStart),
            name: .embraceSessionDidStart,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func onSessionStart(notification: Notification) {
        counter.withLock {
            $0.removeAll()
        }
    }

    func export(logRecords: [ReadableLogRecord], explicitTimeout: TimeInterval?) -> ExportResult {
        guard state == .active else {
            return .failure
        }

        let limits = logBatcher.limits

        for var log in logRecords where validation.execute(log: &log) {

            // do not export crash logs (unless they come from metrickit)
            if log.isEmbType(.crash)
                && log.attributes[LogSemantics.Crash.keyProvider] != .string(LogSemantics.Crash.metrickitProvider) {
                continue
            }

            // apply log limits (ignoring internal logs, crashes and hangs)
            let canExport = counter.withLock {
                guard !log.isEmbType(.internal),
                    !log.isEmbType(.crash),
                    !log.isEmbType(.hang)
                else {
                    return true
                }

                let level = limitLevel(for: log.severity?.toLogSeverity())
                let currentCount = $0[level] ?? 0

                if currentCount >= limits.limitForLevel(level) {
                    return false
                }

                $0[level] = currentCount + 1
                return true
            }

            if canExport {
//                self.logBatcher.addLogRecord(logRecord: log)
            }
        }

        return .success
    }

    func shutdown(explicitTimeout: TimeInterval?) {
        state = .inactive
    }

    /// Everything is always persisted on disk, so calling this method has no effect at all.
    /// - Returns: `ExportResult.success`
    func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
        .success
    }

    func limitLevel(for severity: EmbraceLogSeverity?) -> LogLevel {
        guard let severity = severity else {
            return .info
        }

        if severity.rawValue < EmbraceLogSeverity.warn.rawValue {
            return .info
        }

        if severity.rawValue >= EmbraceLogSeverity.error.rawValue {
            return .error
        }

        return .warning
    }
}

extension LogsLimits {
    func limitForLevel(_ level: LogLevel) -> UInt {
        switch level {
        case .warning: return warning
        case .error: return error
        default: return info
        }
    }
}
