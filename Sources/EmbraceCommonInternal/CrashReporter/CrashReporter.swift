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

public protocol TerminationAttributeValue {}
extension String: TerminationAttributeValue {}
extension Int: TerminationAttributeValue {}
extension Int8: TerminationAttributeValue {}
extension Int16: TerminationAttributeValue {}
extension Int32: TerminationAttributeValue {}
extension Int64: TerminationAttributeValue {}
extension UInt: TerminationAttributeValue {}
extension UInt8: TerminationAttributeValue {}
extension UInt16: TerminationAttributeValue {}
extension UInt32: TerminationAttributeValue {}
extension UInt64: TerminationAttributeValue {}
extension Bool: TerminationAttributeValue {}
extension Double: TerminationAttributeValue {}

public struct TerminationMetadata {
    public let processId: String
    public let timestamp: Date
    public let metadata: [String: TerminationAttributeValue]

    public init(processId: String, timestamp: Date, metadata: [String: TerminationAttributeValue]) {
        self.processId = processId
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

public protocol TerminationReporter {

    func fetchUnsentTerminationAttributes() async -> [TerminationMetadata]
}
