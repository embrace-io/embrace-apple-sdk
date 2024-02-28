//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

@objc public enum LastRunState: Int {
    case invalid, crash, cleanExit
}

@objc public protocol CrashReporter {
    @objc var currentSessionId: String? { get set }

    @objc func install(context: CrashReporterContext)
    @objc func start()

    @objc func getLastRunState() -> LastRunState

    @objc func fetchUnsentCrashReports(completion: @escaping ([CrashReport]) -> Void)
    @objc func deleteCrashReport(id: Int)
}

@objc public class CrashReport: NSObject {
    public private(set) var id: UUID
    public private(set) var ksCrashId: Int
    public private(set) var sessionId: String?
    public private(set) var timestamp: Date?
    public private(set) var dictionary: [String: Any]

    public init(ksCrashId: Int, sessionId: String?, timestamp: Date?, dictionary: [String: Any]) {
        self.id = UUID()
        self.ksCrashId = ksCrashId
        self.sessionId = sessionId
        self.timestamp = timestamp
        self.dictionary = dictionary
    }
}
