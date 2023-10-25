//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public enum LastRunState {
    case invalid, crash, cleanExit
}

public protocol CrashReporter {
    var currentSessionId: SessionId? { get set }
    var sdkVersion: String? { get set }

    func configure(appId: String?, path: String?)

    func getLastRunState() -> LastRunState

    func fetchUnsentCrashReports(completion: @escaping ([CrashReport]) -> Void)
    func deleteCrashReport(id: Int)
}

public struct CrashReport {
    public private(set) var id: UUID
    public private(set) var ksCrashId: Int
    public private(set) var sessionId: SessionId?
    public private(set) var timestamp: Date?
    public private(set) var dictionary: [String: Any]

    public init(ksCrashId: Int, sessionId: SessionId?, timestamp: Date?, dictionary: [String: Any]) {
        self.id = UUID()
        self.ksCrashId = ksCrashId
        self.sessionId = sessionId
        self.timestamp = timestamp
        self.dictionary = dictionary
    }
}
