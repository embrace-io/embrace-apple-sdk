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

    private var sessionLifecycle: SessionLifecycle
    private var storage: EmbraceStorage?

    private override init() {
        fatalError("Use init(options:) instead")
    }

    private init(options: EmbraceOptions) {
        self.options = options

        storage = StorageUtils.createStorage(options: options)

        // TODO: Discuss what to do if the storage fails to initialize!

        let sessionStorageInterface = SessionStorageInterface(storage: storage)
        sessionLifecycle = iOSSessionLifecyle(storageInterface: sessionStorageInterface)

        super.init()

        EmbraceOTel.setup(storage: storage!)
    }

    @objc public class func setup(options: EmbraceOptions) {
        if client != nil {
            print("Embrace was already initialized!")
            return
        }

        client = Embrace(options: options)
    }

    @objc public func start() {
        sessionLifecycle.isEnabled = true
    }

    @objc public func currentSessionId() -> String? {
        // TODO: Discuss concurrency
        return sessionLifecycle.currentSessionId
    }

    @objc public func startNewSession() {
        sessionLifecycle.startNewSession()
    }

    @objc public func stopCurrentSession() {
        sessionLifecycle.stopCurrentSession()
    }
}
