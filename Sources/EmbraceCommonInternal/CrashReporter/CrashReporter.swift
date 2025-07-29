//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

@objc public enum LastRunState: Int {
    case unavailable, crash, cleanExit
}

@objc public class CrashReporterInfoKey: NSObject {
    static public let sessionId = "emb-sid"
    static public let sdkVersion = "emb-sdk"
}

@objc public protocol CrashReporter {

    @objc func install(context: CrashReporterContext) throws

    @objc func fetchUnsentCrashReports(completion: @escaping ([EmbraceCrashReport]) -> Void)
    @objc var onNewReport: ((EmbraceCrashReport) -> Void)? { get set }

    @objc func getLastRunState() -> LastRunState

    @objc func deleteCrashReport(_ report: EmbraceCrashReport)

    @objc var disableMetricKitReports: Bool { get }

    @objc func appendCrashInfo(key: String, value: String?)
    @objc func getCrashInfo(key: String) -> String?

    @objc var basePath: String? { get }
}

@objc public class EmbraceCrashReport: NSObject {
    public private(set) var id: UUID
    public private(set) var payload: String
    public private(set) var provider: String
    public private(set) var internalId: Int?
    public private(set) var sessionId: String?
    public private(set) var timestamp: Date?
    public private(set) var signal: CrashSignal?

    public init(
        payload: String,
        provider: String,
        internalId: Int? = nil,
        sessionId: String? = nil,
        timestamp: Date? = nil,
        signal: CrashSignal? = nil
    ) {
        self.id = UUID()
        self.payload = payload
        self.provider = provider
        self.internalId = internalId
        self.sessionId = sessionId
        self.timestamp = timestamp
        self.signal = signal
    }
}
