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

public typealias FrameAddress = UInt

@objc public protocol Backtracer {

    /// Take a backtrace and return an array of addresses for for each frame.
    @objc func backtrace(of thread: pthread_t) -> [FrameAddress]
}

@objc public class SymbolicatedFrame: NSObject {
    public let returnAddress: FrameAddress
    public let callInstruction: FrameAddress
    public let symbolAddress: FrameAddress
    public let symbolName: String?
    public let imageName: String?
    public let imageUUID: String?
    public let imageAddress: FrameAddress
    public let imageSize: UInt64

    @objc public init(
        returnAddress: FrameAddress, callInstruction: FrameAddress, symbolAddress: FrameAddress, symbolName: String?, imageName: String?, imageUUID: String?, imageAddress: FrameAddress,
        imageSize: UInt64
    ) {
        self.returnAddress = returnAddress
        self.callInstruction = callInstruction
        self.symbolAddress = symbolAddress
        self.symbolName = symbolName
        self.imageName = imageName
        self.imageUUID = imageUUID
        self.imageAddress = imageAddress
        self.imageSize = imageSize
    }
}

@objc public protocol Symbolicator {

    /// Take a frame address and return info about it.
    @objc func symbolicate(address: FrameAddress) -> SymbolicatedFrame?
}
