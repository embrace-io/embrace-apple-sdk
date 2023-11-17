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

    @objc public private(set) static var client: Embrace?
    @objc public private(set) var options: Embrace.Options
    @objc public private(set) var started: Bool
    @objc public private(set) var deviceId: UUID?

    @objc public var logLevel: LogLevel = .error {
        didSet {
            ConsoleLog.shared.level = logLevel
        }
    }

    let sessionLifecycle: SessionLifecycle
    let config: EmbraceConfig
    let storage: EmbraceStorage?
    let upload: EmbraceUpload?
    let collection: DataCollection

    private let processingQueue: DispatchQueue
    private static let synchronizationQueue: DispatchQueue = DispatchQueue(label: "com.embrace.synchronization", qos: .utility)

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

            client = Embrace(options: options)
        }
    }

    private override init() {
        fatalError("Use init(options:) instead")
    }

    private init(options: Embrace.Options) {
        self.started = false
        self.options = options

        self.storage = Embrace.createStorage(options: options)
        self.deviceId = EmbraceDeviceId.retrieve(from: self.storage)
        self.collection = DataCollection(options: options)
        self.upload = Embrace.createUpload(options: options, deviceId: KeychainAccess.deviceId.uuidString)
        self.config = Embrace.createConfig(options: options, deviceId: KeychainAccess.deviceId.uuidString)

        self.processingQueue = DispatchQueue(label: "com.embrace.processing", qos: .background, attributes: .concurrent)

        // sessions lifecycle
        let sessionStorageInterface = SessionStorageInterface(storage: storage)
        #if os(iOS)
            sessionLifecycle = iOSSessionLifecyle(storageInterface: sessionStorageInterface)
        #else
            sessionLifecycle = ManualSessionLifecyle(storageInterface: sessionStorageInterface)
        #endif
        super.init()

        initializeSessionHandlers()
        initializeCrashReporter(options: options)

        EmbraceOTel.setup(storage: storage!)
    }

    @objc public func start() throws {
        if !Thread.isMainThread {
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

            started = true
            sessionLifecycle.isEnabled = true
            collection.start()

            // send unsent sessions and crash reports
            processingQueue.async { [weak self] in
                UnsentDataHandler.sendUnsentData(
                    storage: self?.storage,
                    upload: self?.upload,
                    crashReporter: self?.collection.crashReporter
                )
            }
        }
    }

    @objc public func currentSessionId() -> String? {
        guard config.isSDKEnabled else {
            return nil
        }

        // TODO: Discuss concurrency
        return sessionLifecycle.currentSessionId
    }

    @objc public func startNewSession() {
        sessionLifecycle.startNewSession()
    }

    @objc public func endCurrentSession() {
        sessionLifecycle.endCurrentSession()
    }

    // this is temp just so we can test collecting and storing resources into the database
    // TODO: Replace this with intended otel way of collecting resources
    public func addResource(key: String, value: String) throws {
        try storage?.addResource(key: key, value: value, resourceType: .process, resourceTypeId: sessionLifecycle.storageInterface.processId.uuidString)
    }

    public func addResource(key: String, value: Int) throws {
        try storage?.addResource(key: key, value: value, resourceType: .process, resourceTypeId: sessionLifecycle.storageInterface.processId.uuidString)
    }

    public func addResource(key: String, value: Double) throws {
        try storage?.addResource(key: key, value: value, resourceType: .process, resourceTypeId: sessionLifecycle.storageInterface.processId.uuidString)
    }
}
