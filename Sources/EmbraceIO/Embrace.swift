//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import EmbraceOTel
import EmbraceStorage
import EmbraceUpload
import EmbraceObjCUtils

@objc public class Embrace: NSObject {

    @objc public private(set) static var client: Embrace?
    @objc public private(set) var options: EmbraceOptions
    @objc public private(set) var started: Bool

    private let sessionLifecycle: SessionLifecycle
    private let storage: EmbraceStorage?
    private let upload: EmbraceUpload?
    private let collectors: CollectorsManager
    private var crashReporter: CrashReporter?

    private let processingQueue: DispatchQueue
    private static let synchronizationQueue: DispatchQueue = DispatchQueue(label: "com.embrace.synchronization", qos: .utility)

    private override init() {
        fatalError("Use init(options:) instead")
    }

    private init(options: EmbraceOptions, collectors: [Collector]) {
        self.started = false
        self.options = options
        self.collectors = CollectorsManager(collectors: collectors)
        self.storage = Embrace.createStorage(options: options)
        self.upload = Embrace.createUpload(options: options)

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
        initializeCrashReporter(options: options, collectors: collectors)

        EmbraceOTel.setup(storage: storage!)
    }

    private func getMetaData() {
    }

    @objc public class func setup(options: EmbraceOptions, collectors: [Collector]) {
        Embrace.synchronizationQueue.sync {
            if client != nil {
                print("Embrace was already initialized!")
                return
            }

            client = Embrace(options: options, collectors: collectors)
        }
    }

    @objc public func start() {
        Embrace.synchronizationQueue.sync {
            guard started == false else {
                print("Embrace was already started!")
                return
            }

            started = true
            sessionLifecycle.isEnabled = true
            collectors.start()

            // send unsent sessions and crash reports
            processingQueue.async { [weak self] in
                UnsentDataHandler.sendUnsentData(
                    storage: self?.storage,
                    upload: self?.upload,
                    crashReporter: self?.crashReporter
                )
            }
        }
    }

    @objc public func currentSessionId() -> String? {
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

    // MARK: - Private
    private static func createStorage(options: EmbraceOptions) -> EmbraceStorage? {
        if let storageUrl = EmbraceFileSystem.storageDirectoryURL(
            appId: options.appId,
            appGroupId: options.appGroupId,
            forceCachesDirectory: options.platform == .tvOS // TODO: Check if this is really needed
        ) {
            do {
                let storageOptions = EmbraceStorage.Options(baseUrl: storageUrl, fileName: "db.sqlite")
                return try EmbraceStorage(options: storageOptions)
            } catch {
                print("Error initializing Embrace Storage: " + error.localizedDescription)
            }
        } else {
            print("Error initializing Embrace Storage!")
        }

        // TODO: Discuss what to do if the storage fails to initialize!
        return nil
    }

    private static func createUpload(options: EmbraceOptions) -> EmbraceUpload? {
        // endpoints
        guard let sessionsURL = URL.sessionsEndpoint(basePath: options.endpointsConfig.dataBaseUrlPath),
              let blobsURL = URL.blobsEndpoint(basePath: options.endpointsConfig.dataBaseUrlPath) else {
            print("Failed to initialize endpoints!")
            return nil
        }

        let endpoints = EmbraceUpload.EndpointOptions(sessionsURL: sessionsURL, blobsURL: blobsURL)

        // cache
        guard let cacheUrl = EmbraceFileSystem.uploadsDirectoryPath(
            appId: options.appId,
            appGroupId: options.appGroupId,
            forceCachesDirectory: options.platform == .tvOS // TODO: Check if this is really needed
        ),
              let cache = EmbraceUpload.CacheOptions(cacheBaseUrl: cacheUrl)
        else {
            print("Failed to initialize upload cache!")
            return nil
        }

        // metadata
        let metadata = EmbraceUpload.MetadataOptions(
            apiKey: options.appId,
            userAgent: "Embrace/i/6.0.0", // TODO: Do this properly!
            deviceId: "0123456789ABCDEF0123456789ABCDEF"  // TODO: Do this properly!
        )

        do {
            let options = EmbraceUpload.Options(endpoints: endpoints, cache: cache, metadata: metadata)
            let queue = DispatchQueue(label: "com.embrace.upload", attributes: .concurrent)

            return try EmbraceUpload(options: options, queue: queue)
        } catch {
            print("Error initializing Embrace Upload: " + error.localizedDescription)
        }

        return nil
    }

    private func initializeSessionHandlers() {
        // on new session handler
        sessionLifecycle.onNewSession = { [weak self] sessionId in
            self?.crashReporter?.currentSessionId = sessionId
        }

        // on session ended handler
        sessionLifecycle.onSessionEnded = { [weak self] _ in
            self?.crashReporter?.currentSessionId = nil
        }
    }

    private func initializeCrashReporter(options: EmbraceOptions, collectors: [Collector]) {
        // TODO: Handle multiple crash reporters!

        // find crash reporter and set folder path for crashes
        crashReporter = collectors.first(where: { $0 is CrashReporter }) as? any CrashReporter

        if crashReporter == nil {
            print("Not using Embrace's crash reporter")
            return
        }

        print("Using Embrace's crash reporter.")

        let crashesPath = EmbraceFileSystem.crashesDirectoryPath(
            appId: options.appId,
            appGroupId: options.appGroupId,
            forceCachesDirectory: options.platform == .tvOS // TODO: Check if this is really needed
        )?.path

        crashReporter?.configure(appId: options.appId, path: crashesPath)

        crashReporter?.sdkVersion = "6.0.0" // TODO: Do this properly!
    }
}
