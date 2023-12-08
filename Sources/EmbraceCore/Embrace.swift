//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import EmbraceConfig
import EmbraceOTel
import EmbraceStorage
import EmbraceUpload
import EmbraceObjCUtils

@objc public class Embrace: NSObject {

    @objc public internal(set) static var client: Embrace?

    @objc public private(set) var options: Embrace.Options

    @objc public private(set) var started: Bool

    @objc public private(set) var deviceId: UUID

    @objc public var logLevel: LogLevel = .error {
        didSet {
            ConsoleLog.shared.level = logLevel
        }
    }

    let config: EmbraceConfig
    let storage: EmbraceStorage
    let upload: EmbraceUpload?
    let captureServices: CaptureServices

    let sessionController: SessionController
    let sessionLifecycle: SessionLifecycle

    private let processingQueue = DispatchQueue(
        label: "com.embrace.processing",
        qos: .background,
        attributes: .concurrent
    )
    private static let synchronizationQueue = DispatchQueue(
        label: "com.embrace.synchronization",
        qos: .utility
    )

    @objc public static func setup(options: Embrace.Options) throws {
        if !Thread.isMainThread {
            throw EmbraceSetupError.invalidThread("Embrace must be setup on the main thread")
        }

        try Embrace.synchronizationQueue.sync {
            if client != nil {
                ConsoleLog.warning("Embrace was already initialized!")
                return
            }

            try options.validateAppId()
            try options.validateGroupId()

            client = try Embrace(options: options)
        }
    }

    private override init() {
        fatalError("Use init(options:) instead")
    }

    private init(options: Embrace.Options) throws {
        self.started = false
        self.options = options

        self.storage = try Embrace.createStorage(options: options)
        self.deviceId = EmbraceDeviceId.retrieve(from: self.storage)
        self.captureServices = CaptureServices(options: options)
        self.upload = Embrace.createUpload(options: options, deviceId: KeychainAccess.deviceId.uuidString)
        self.config = Embrace.createConfig(options: options, deviceId: KeychainAccess.deviceId.uuidString)
        self.sessionController = SessionController(storage: self.storage, upload: self.upload)
        self.sessionLifecycle = Embrace.createSessionLifecycle(
            platform: options.platform,
            controller: sessionController
        )

        super.init()

        EmbraceOTel.setup(spanProcessor: .with(storage: storage))
        sessionLifecycle.setup()
    }

    @objc public func start() throws {
        guard Thread.isMainThread else {
            throw EmbraceSetupError.invalidThread("Embrace must be started on the main thread")
        }

        Embrace.synchronizationQueue.sync {
            guard started == false else {
                ConsoleLog.warning("Embrace was already started!")
                return
            }

            guard config.isSDKEnabled else {
                ConsoleLog.warning("Embrace can't start when disabled!")
                return
            }

            let processStartSpan = createProcessStartSpan()
            defer { processStartSpan.end() }
            recordSpan(name: "emb-sdk-start", parent: processStartSpan, type: .performance) { _ in
                started = true

                sessionLifecycle.start()
                captureServices.start()

                // send unsent sessions and crash reports
                processingQueue.async { [weak self] in
                    UnsentDataHandler.sendUnsentData(
                        storage: self?.storage,
                        upload: self?.upload,
                        currentSessionId: self?.sessionController.currentSession?.id,
                        crashReporter: self?.captureServices.crashReporter
                    )
                }
            }
        }
    }

    @objc public func currentSessionId() -> String? {
        guard config.isSDKEnabled else {
            return nil
        }

        return sessionController.currentSession?.id.toString
    }

    @objc public func startNewSession() {
        sessionLifecycle.startSession()
    }

    @objc public func endCurrentSession() {
        sessionLifecycle.endSession()
    }
}
