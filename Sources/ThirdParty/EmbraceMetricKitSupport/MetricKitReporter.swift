//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if canImport(MetricKit)
    import MetricKit
#endif

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceObjCUtilsInternal
    import EmbraceMetricKitSupportObjC
#endif

#if canImport(KSCrashRecording)
    import KSCrashRecording
#elseif canImport(KSCrash)
    import KSCrash
#endif

#if os(iOS)

    public class MetricKitReporterLogger {
        var internalLogger: InternalLogger?
        let osLogger = OSLog(subsystem: "MetricKitReporterLogger", category: "log")

        func trace(_ message: String) {
            let msg = "[MRK] \(message)"
            internalLogger?.trace(msg)
            // os_log("%{public}s", log: osLogger, msg)
        }

        func debug(_ message: String) {
            let msg = "[MRK] \(message)"
            internalLogger?.debug(msg)
            // os_log("%{public}s", log: osLogger, msg)
        }

        func info(_ message: String) {
            let msg = "[MRK] \(message)"
            internalLogger?.info(msg)
            // os_log("%{public}s", log: osLogger, msg)
        }

        func warning(_ message: String) {
            let msg = "[MRK] \(message)"
            internalLogger?.warning(msg)
            // os_log("%{public}s", log: osLogger, msg)
        }

        func error(_ message: String) {
            let msg = "[MRK] \(message)"
            internalLogger?.error(msg)
            // os_log("%{public}s", log: osLogger, msg)
        }

        func startup(_ message: String) {
            let msg = "[MRK] \(message)"
            internalLogger?.startup(msg)
            // os_log("%{public}s", log: osLogger, msg)
        }

        func critical(_ message: String) {
            let msg = "[MRK] \(message)"
            internalLogger?.critical(msg)
            // os_log("%{public}s", log: osLogger, msg)
        }
    }

    // optionally, we can have a timer that sets the date
    // in a threadcrumb or logger so we know when the
    // crash actually hapenned.

    // MARK: - Reporter
    @available(iOS 13.0, *)
    public class MetricKitReporter: NSObject, CrashReporter, TerminationReporter {

        private var reports = EmbraceMutex([EmbraceCrashReport]())
        private var lastSession: String?
        private var crashContext: CrashReporterContext?
        private var threadcrumb: EmbraceThreadcrumb?
        private var logger: MetricKitReporterLogger = MetricKitReporterLogger()
        private var payloadSemaphore = DispatchSemaphore(value: 0)

        private var lastSessionURL: URL {
            try! FileManager.default.url(
                for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false
            ).appendingPathComponent("last_session")
        }

        private var symbolDirectoryURL: URL! {
            let url = try! FileManager.default.url(
                for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false
            ).appendingPathComponent("ThreadcrumbSymbols")
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        }

        public override init() {
            super.init()
            self.lastSession = try? String(contentsOf: lastSessionURL, encoding: .utf8)
            self.threadcrumb = EmbraceThreadcrumb()
            logger.info("init")
        }

        deinit {
            MXMetricManager.shared.remove(self)
        }

        public var basePath: String? {
            nil
        }

        public var disableMetricKitReports: Bool {
            true  // not us, the other implementation
        }

        public var onNewReport: ((EmbraceCrashReport) -> Void)?

        public func getLastRunState() -> LastRunState {
            .unavailable
        }

        public func install(context: CrashReporterContext) throws {
            crashContext = context
            logger.internalLogger = context.logger
            logger.info("install")

            // install KSCrash as a shell only.
            // It won't write any reports, but will notify
            // us so we can store the info we need to
            // complement MetricKit. Wahahaha!
            let config = KSCrashConfiguration()
            config.enableSigTermMonitoring = true
            config.enableSwapCxaThrow = false
            config.enableQueueNameSearch = false
            config.installPath = context.filePathProvider.directoryURL(for: "mk_crash_reporter")?.path
            config.reportStoreConfiguration.appName = context.appId ?? "default"
            config.willWriteReportCallback = EMBTerminationStorageWillWriteCrashEvent
            config.monitors = [.cppException, .machException, .nsException, .signal]
            do {
                try KSCrash.shared.install(with: config)
            } catch {
                logger.error("KSCrash install failed \(error)")
            }

            MXMetricManager.shared.add(self)
            let mxLogger = MXMetricManager.makeLogHandle(category: ProcessIdentifier.current.value)
            mxSignpost(.event, log: mxLogger, name: "embrace_uuid")
        }

        public func fetchUnsentTerminationAttributes() async -> [TerminationMetadata] {
            let identifiers: [String] = EMBTerminationStorageGetIdentifiers()
            return identifiers.compactMap { id in
                var storage = EMBTerminationStorage()
                let ok = withUnsafeMutablePointer(to: &storage) { ptr in
                    EMBTerminationStorageForIdentifier(id, ptr)
                }
                if ok {
                    return TerminationMetadata(
                        processId: storage.processIdentifier,
                        timestamp: storage.lastKnownDate,
                        metadata: storage.toDictionary()
                    )
                }
                return nil
            }
        }

        public func fetchUnsentCrashReports(completion: @escaping ([EmbraceCrashReport]) -> Void) {

            logger.info("pre-dispatch waiting for payloads")

            DispatchQueue.global(qos: .utility).async { [self] in

                defer {
                    let results = reports.safeValue
                    logger.info("received \(results.count) payloads")
                    completion(results)
                }

                logger.info("waiting for payloads[1]")
                guard payloadSemaphore.wait(timeout: .now() + 2.0) == .timedOut else {
                    return
                }
                logger.info("no payloads received after 2 seconds[1]")

                logger.info("waiting for payloads[2]")
                guard payloadSemaphore.wait(timeout: .now() + 5.0) == .timedOut else {
                    return
                }
                logger.info("no payloads received after 5 seconds[2]")
            }
        }

        public func deleteCrashReport(_ report: EmbraceCrashReport) {
            logger.info("deleteCrashReport")
        }

        private func _writeSymbols(_ symbols: [UInt64], sessionId: String, processId: String, sdk: String?) {

            logger.info("_writeSymbols")

            guard symbols.count == 32 else {
                logger.error("received \(symbols.count) symbols, expected 32")
                return
            }

            // we're looking for a thread with 39 frames.
            // `__impact_threadcrumb_end__`
            // => ... 32 frames of `__impact__<N>__` for the GUID of the session it was part of (no hyphens).
            // `__impact_threadcrumb_start__`
            // `_pthread_start`
            // `thread_start`
            var combinedHash: UInt64 = 0
            for i in (0..<32) {
                let addr: UInt64 = symbols[i]
                logger.info("\(i) => frame addr: \(addr)")
                let shift = UInt64((i % 63) + 1)  // use zero-based index
                let rotated = (addr << shift) | (addr >> (64 - shift))
                combinedHash ^= rotated
            }
            let filename = String(format: "%016llx.stacksym", combinedHash)
            let url = symbolDirectoryURL.appendingPathComponent(filename)
            let output = [sessionId, processId, sdk].compactMap { $0 }.joined(separator: "\n")
            try? output.write(to: url, atomically: false, encoding: .utf8)
        }

        public func appendCrashInfo(key: String, value: String?) {
            if key == CrashReporterInfoKey.sessionId {
                if let value {

                    // log it
                    logger.info("sid: \(value)")
                    let stack = threadcrumb?.log(value).map { UInt64(truncating: $0) } ?? []
                    _writeSymbols(
                        stack, sessionId: value, processId: ProcessIdentifier.current.value,
                        sdk: crashContext?.sdkVersion)

                    try? value.write(to: lastSessionURL, atomically: false, encoding: .utf8)
                    let logger = MXMetricManager.makeLogHandle(category: value)
                    mxSignpost(.event, log: logger, name: "emb_sid")
                }
            } else if key == CrashReporterInfoKey.sdkVersion {

                if let value {
                    let logger = MXMetricManager.makeLogHandle(category: value)
                    mxSignpost(.event, log: logger, name: "emb_sdk")
                }
            }
        }

        public func getCrashInfo(key: String) -> String? {
            nil
        }
    }

    // MARK: - MetricKit Subscriber

    @available(iOS 13.0, *)
    extension MetricKitReporter: MXMetricManagerSubscriber {

        @available(iOS 14.0, *)
        @objc public func didReceive(_ payloads: [MXDiagnosticPayload]) {

            logger.info("\(#function) \(payloads.count) payload(s)")

            DispatchQueue.global(qos: .utility).async { [self] in
                for payload in payloads {
                    payload.crashDiagnostics?.forEach { crash in
                        if let report = handleCrash(
                            crash,
                            timeStampBegin:
                                payload.timeStampBegin,
                            timeStampEnd: payload.timeStampEnd,
                            logger: logger
                        ) {
                            reports.withLock {
                                $0.append(report)
                            }
                        }
                    }
                }

                logger.info("signaling that we're done collecting payloads")
                payloadSemaphore.signal()
            }

        }

        @available(iOS 13.0, *)
        @objc public func didReceive(_ payloads: [MXMetricPayload]) {
            DispatchQueue.global(qos: .utility).async {
                payloads.forEach { payload in
                    self.handleMetric(payload)
                }
            }
        }
    }

    // MARK: - Crashes

    @available(iOS 13.0, *)
    extension MetricKitReporter {

        @available(iOS 14.0, *)
        private func handleCrash(
            _ crash: MXCrashDiagnostic,
            timeStampBegin: Date,
            timeStampEnd: Date,
            logger: MetricKitReporterLogger
        ) -> EmbraceCrashReport? {

            #if DEBUG
                if #available(iOS 16.0, *) {
                    let url: URL = .documentsDirectory.appending(
                        component: "diagnostic-\(lastSession ?? UUID().uuidString)"
                    ).appendingPathExtension("json")
                    try? crash.jsonRepresentation().write(to: url)
                }
            #endif

            return crash.buildEmbraceCrashReport(
                sessionId: lastSession,
                timestamp: timeStampEnd,
                logger: logger
            )
        }

        private func _match(on: String, pattern: String) -> String? {
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                return nil
            }

            if let match = regex.firstMatch(in: on, range: NSRange(on.startIndex..., in: on)) {
                let range = match.range(at: 1)
                if let foundRange = Range(range, in: on) {
                    return String(on[foundRange])
                }
            }
            return nil
        }
    }

    // MARK: - Metrics

    @available(iOS 13.0, *)
    extension MetricKitReporter {

        private func handleMetric(_ metric: MXMetricPayload) {

            #if DEBUG
                if #available(iOS 16.0, *) {
                    let url: URL = .documentsDirectory.appending(
                        component: "metric-\(lastSession ?? UUID().uuidString)"
                    )
                    .appendingPathExtension("json")
                    try? metric.jsonRepresentation().write(to: url)
                }
            #endif

            /*
            let attsNoHistogramOptional = [String: String?](
                uniqueKeysWithValues: _flatten(
                    metric.dictionaryRepresentation()
                )
                .compactMap { key, value in
                    if key.contains("histogram") {
                        return (key, nil)
                    }
                    return (key, String(describing: value))
                })
            let attsNoHistogram = attsNoHistogramOptional.compactMapValues { $0 }
            
            
             try? JSONSerialization
             .data(withJSONObject: attsNoHistogram, options: [.prettyPrinted, .sortedKeys])
             .write(to: .documentsDirectory.appending(component: "metric_no_hist.json"))
             */

            /*
            Embrace.client?.log(
                "mk.metric",
                severity: .info,
                timestamp: metric.timeStampEnd,
                attributes: attsNoHistogram,
                stackTraceBehavior: .notIncluded
            )
             */
        }

        private func _flatten(_ value: Any, prefix: String = "") -> [String: Any] {
            var result: [String: Any] = [:]

            switch value {
            case let dict as [String: Any]:
                for (key, subvalue) in dict {
                    let newPrefix = prefix.isEmpty ? key : "\(prefix).\(key)"
                    result.merge(_flatten(subvalue, prefix: newPrefix)) { (_, new) in new }
                }

            case let array as [Any]:
                for (index, item) in array.enumerated() {
                    let newPrefix = "\(prefix)[\(index)]"
                    result.merge(_flatten(item, prefix: newPrefix)) { (_, new) in new }
                }

            default:
                result[prefix] = value
            }

            return result
        }

    }

#else

    public class MetricKitReporter: NSObject, CrashReporter {
        public func install(context: EmbraceCommonInternal.CrashReporterContext) throws {
        }

        public func fetchUnsentCrashReports(completion: @escaping ([EmbraceCommonInternal.EmbraceCrashReport]) -> Void) {
        }

        public var onNewReport: ((EmbraceCommonInternal.EmbraceCrashReport) -> Void)?

        public func getLastRunState() -> EmbraceCommonInternal.LastRunState {
            .unavailable
        }

        public func deleteCrashReport(_ report: EmbraceCommonInternal.EmbraceCrashReport) {
        }

        public let disableMetricKitReports: Bool = false

        public func appendCrashInfo(key: String, value: String?) {
        }

        public func getCrashInfo(key: String) -> String? {
            nil
        }

        public var basePath: String?

    }

#endif  //
