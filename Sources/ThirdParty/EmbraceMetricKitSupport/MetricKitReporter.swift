import Foundation
import MetricKit

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

#if os(iOS) || os(macOS)

// MARK: - Reporter
@available(iOS 13.0, macOS 12.0, *)
public class MetricKitReporter: NSObject, CrashReporter {

    private let receivedCrashesSemaphore = DispatchSemaphore(value: 0)
    private var reports = EmbraceMutex([EmbraceCrashReport]())
    private var lastSession: String?

    // we can either process crashes from the delegate callback (true),
    // or just process all crashes when they are requested (false).
    // The latter is preferred.
    private let processOnSubscription: Bool = false

    public override init() {
        if #available(iOS 16.0, *) {
            let url: URL = .applicationSupportDirectory.appending(path: "last_session")
            self.lastSession = try? String(contentsOf: url, encoding: .utf8)
        }
        super.init()
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
        MXMetricManager.shared.add(self)
        let logger = MXMetricManager.makeLogHandle(category: ProcessIdentifier.current.value)
        mxSignpost(.event, log: logger, name: "embrace_uuid")
    }

    public func fetchUnsentCrashReports(completion: @escaping ([EmbraceCrashReport]) -> Void) {
        DispatchQueue.global(qos: .utility).async { [self] in

            print("[MetricKitReporter] waiting for payloads")

            if processOnSubscription {

                // wait for all crashes to come in, max 20 seconds
                _ = receivedCrashesSemaphore.wait(wallTimeout: .now() + 20.0)

            } else {

                // simply process the past payloads
                if #available(iOS 14.0, *) {
                    MXMetricManager.shared.pastDiagnosticPayloads.forEach { payload in
                        payload.crashDiagnostics?.forEach { crash in
                            self.handleCrash(
                                crash, timeStampBegin: payload.timeStampBegin, timeStampEnd: payload.timeStampEnd)
                        }
                    }
                }

            }

            let reports = reports.safeValue
            print("[MetricKitReporter] received \(reports.count) payloads")

            completion(reports)

        }
    }

    public func deleteCrashReport(_ report: EmbraceCrashReport) {
    }

    public func appendCrashInfo(key: String, value: String?) {
        if key == CrashReporterInfoKey.sessionId {
            if let value {
                if #available(iOS 16.0, *) {
                    let url: URL = .applicationSupportDirectory.appending(path: "last_session")
                    try? value.write(to: url, atomically: false, encoding: .utf8)
                }

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
        guard processOnSubscription else {
            return
        }
        DispatchQueue.global(qos: .utility).async { [self] in
            payloads.forEach { payload in
                payload.crashDiagnostics?.forEach { crash in
                    self.handleCrash(crash, timeStampBegin: payload.timeStampBegin, timeStampEnd: payload.timeStampEnd)
                }
            }
            // flag the system that we have all the reports
            receivedCrashesSemaphore.signal()
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

@available(iOS 13.0, macOS 12.0, *)
extension MetricKitReporter {

    @available(iOS 14.0, *)
    private func handleCrash(_ crash: MXCrashDiagnostic, timeStampBegin: Date, timeStampEnd: Date) {

        #if DEBUG
            if #available(iOS 16.0, *) {
                let url: URL = .documentsDirectory.appending(
                    component: "diagnostic-\(lastSession ?? UUID().uuidString)"
                ).appendingPathExtension("json")
                try? crash.jsonRepresentation().write(to: url)
            }
        #endif

        if let report = crash.buildEmbraceCrashReport(
            sessionId: lastSession,
            timestamp: timeStampEnd
        ) {
            reports.withLock {
                $0.append(report)
            }
        }
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
