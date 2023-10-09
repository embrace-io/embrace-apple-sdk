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
    var appVersion: String? { get set }

    func configure(appId: String?, path: String?)

    func getLastRunState() -> LastRunState

    func fetchUnsentCrashReports(completion: @escaping ([CrashReport]) -> Void)
    func deleteCrashReport(id: Int)
}

public struct CrashReport {
    public private(set) var id: Int
    public private(set) var sessionId: SessionId?
    public private(set) var sdkVersion: String?
    public private(set) var appVersion: String?
    public private(set) var timestamp: Date?
    public private(set) var data: Data

    public init(id: Int, sessionId: SessionId?, sdkVersion: String?, appVersion: String?, timestamp: Date?, data: Data) {
        self.id = id
        self.sessionId = sessionId
        self.sdkVersion = sdkVersion
        self.appVersion = appVersion
        self.timestamp = timestamp
        self.data = data
    }
}
