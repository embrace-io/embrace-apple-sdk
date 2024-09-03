//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

@objc public enum LastRunState: Int {
    case unavailable, crash, cleanExit
}

@objc public protocol CrashReporter {
    @objc var currentSessionId: String? { get set }

    @objc func install(context: CrashReporterContext, logger: InternalLogger)

    @objc func getLastRunState() -> LastRunState

    @objc func fetchUnsentCrashReports(completion: @escaping ([CrashReport]) -> Void)
    @objc func deleteCrashReport(id: Int)

    @objc var onNewReport: ((CrashReport) -> Void)? { get set }
}

public protocol ExtendableCrashReporter: CrashReporter {
    func appendCrashInfo(key: String, value: String)
}

@objc public class CrashReport: NSObject {
    public private(set) var id: UUID
    public private(set) var payload: String
    public private(set) var provider: String
    public private(set) var internalId: Int?
    public private(set) var sessionId: String?
    public private(set) var timestamp: Date?

    public init(
        payload: String,
        provider: String,
        internalId: Int? = nil,
        sessionId: String? = nil,
        timestamp: Date? = nil
    ) {
        self.id = UUID()
        self.payload = payload
        self.provider = provider
        self.internalId = internalId
        self.sessionId = sessionId
        self.timestamp = timestamp
    }
}
