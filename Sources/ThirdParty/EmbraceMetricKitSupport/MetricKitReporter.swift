import Foundation
import MetricKit

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceObjCUtilsInternal
#endif

#if os(iOS) || os(macOS)

// MARK: - Reporter
@available(iOS 13.0, macOS 12.0, *)
public class MetricKitReporter: NSObject, CrashReporter {

    private var reports = EmbraceMutex([EmbraceCrashReport]())
    private var lastSession: String? = nil
    private var crashContext: CrashReporterContext?
    private var threadcrumb: EmbraceThreadcrumb? = nil
    
    private var lastSessionURL: URL {
        try! FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent("last_session")
    }
    
    private var symbolDirectoryURL: URL! {
        let url = try! FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent("ThreadcrumbSymbols")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    
    public override init() {
        super.init()
        self.lastSession = try? String(contentsOf: lastSessionURL, encoding: .utf8)
        self.threadcrumb = EmbraceThreadcrumb()
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
        MXMetricManager.shared.add(self)
        let logger = MXMetricManager.makeLogHandle(category: ProcessIdentifier.current.value)
        mxSignpost(.event, log: logger, name: "embrace_uuid")
    }

    public func fetchUnsentCrashReports(completion: @escaping ([EmbraceCrashReport]) -> Void) {
        DispatchQueue.global(qos: .utility).async { [self] in

            crashContext?.logger?.info("[MetricKitReporter] waiting for payloads")

            // simply process the past payloads
            var reports: [EmbraceCrashReport] = []
            
            if #available(iOS 14.0, *) {
                MXMetricManager.shared.pastDiagnosticPayloads.forEach { payload in
                    payload.crashDiagnostics?.forEach { crash in
                        if let report =  handleCrash(
                            crash,
                            timeStampBegin:
                                payload.timeStampBegin,
                            timeStampEnd: payload.timeStampEnd,
                            logger: crashContext?.logger
                        ) {
                            reports.append(report)
                        }
                    }
                }
            }

            crashContext?.logger?.info("[MetricKitReporter] received \(reports.count) payloads")

            completion(reports)

        }
    }

    public func deleteCrashReport(_ report: EmbraceCrashReport) {
    }

    private func _writeSymbols(_ symbols: [UInt64], sessionId: String) {
        
        guard symbols.count == 32 else {
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
            print("\(i) => frame addr: \(addr)")
            let shift = UInt64((i % 63) + 1)  // use zero-based index
            let rotated = (addr << shift) | (addr >> (64 - shift))
            combinedHash ^= rotated
        }
        let filename = String(format: "%016llx.stacksym", combinedHash)
        let url = symbolDirectoryURL.appendingPathComponent(filename)
        try? sessionId.write(to: url, atomically: false, encoding: .utf8)
    }
    
    public func appendCrashInfo(key: String, value: String?) {
        if key == CrashReporterInfoKey.sessionId {
            if let value {
                
                // log it
                crashContext?.logger?.info("[MetricKitReporter] sid: \(value)")
                let stack = threadcrumb?.log(value).map { UInt64($0) } ?? []
                _writeSymbols(stack, sessionId: value)

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

@available(iOS 13.0, macOS 12.0, *)
extension MetricKitReporter: MXMetricManagerSubscriber {

    @available(iOS 14.0, *)
    @objc public func didReceive(_ payloads: [MXDiagnosticPayload]) {
        // not handling this here
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

@available(iOS 13.0, macOS 12.0, *)
extension MetricKitReporter {

    @available(iOS 14.0, *)
    private func handleCrash(
        _ crash: MXCrashDiagnostic,
        timeStampBegin: Date,
        timeStampEnd: Date,
        logger: InternalLogger?
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

@available(iOS 13.0, macOS 12.0, *)
extension MetricKitReporter {

    private func handleMetric(_ metric: MXMetricPayload) {

        #if DEBUG
            if #available(iOS 16.0, *) {
                let url: URL = .documentsDirectory.appending(component: "metric-\(lastSession ?? UUID().uuidString)")
                    .appendingPathExtension("json")
                try? metric.jsonRepresentation().write(to: url)
            }
        #endif

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

        /*
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

@available(iOS 13.0, macOS 12.0, *)
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

#endif //
