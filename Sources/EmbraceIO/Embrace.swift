//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import EmbraceOTel
import EmbraceStorage

@objc public class Embrace: NSObject {

    @objc public private(set) static var client: Embrace?
    @objc public private(set) var options: EmbraceOptions
    @objc public private(set) var started: Bool

    private var sessionLifecycle: SessionLifecycle?
    private var storage: EmbraceStorage?
    private var collectors: CollectorsManager
    private var crashReporter: CrashReporter?

    private override init() {
        fatalError("Use init(options:) instead")
    }

    private init(options: EmbraceOptions, collectors: [Collector]) {
        self.started = false
        self.options = options
        self.collectors = CollectorsManager(collectors: collectors)
        self.storage = Embrace.createStorage(options: options)

        // sessions lifecycle
        let sessionStorageInterface = SessionStorageInterface(storage: storage)
        #if os(iOS)
        sessionLifecycle = iOSSessionLifecyle(storageInterface: sessionStorageInterface)
        #endif
        super.init()

        initializeSessionHandlers()
        initializeCrashReporter(options: options, collectors: collectors)

        EmbraceOTel.setup(storage: storage!)
    }

    @objc public class func setup(options: EmbraceOptions, collectors: [Collector]) {
        // TODO: Concurrency handling!
        
        if client != nil {
            print("Embrace was already initialized!")
            return
        }

        client = Embrace(options: options, collectors: collectors)
    }

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

    private func initializeSessionHandlers() {
        // on new session handler
        sessionLifecycle?.onNewSession = { [weak self] sessionId in
            self?.crashReporter?.currentSessionId = sessionId
        }

        // on session ended handler
        sessionLifecycle?.onSessionEnded = { [weak self] _ in
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
        crashReporter?.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    @objc public func start() {
        guard started == false else {
            print("Embrace was already started!")
            return
        }
        
        started = true
        sessionLifecycle?.isEnabled = true
        collectors.start()
    }

    @objc public func currentSessionId() -> String? {
        // TODO: Discuss concurrency
        return sessionLifecycle?.currentSessionId
    }

    @objc public func startNewSession() {
        sessionLifecycle?.startNewSession()
    }

    @objc public func stopCurrentSession() {
        sessionLifecycle?.stopCurrentSession()
    }
}
