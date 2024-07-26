//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal

class CrashlyticsWrapper {

    class Options {
        let className: String
        let singletonSelector: Selector
        let setValueSelector: Selector

        let maxRetryCount: Int
        let retryDelay: Double

        init(
            className: String,
            singletonSelector: Selector,
            setValueSelector: Selector,
            maxRetryCount: Int,
            retryDelay: Double
        ) {
            self.className = className
            self.singletonSelector = singletonSelector
            self.setValueSelector = setValueSelector
            self.maxRetryCount = maxRetryCount
            self.retryDelay = retryDelay
        }
    }

    @ThreadSafe private(set) var options: CrashlyticsWrapper.Options
    @ThreadSafe private(set) var instance: AnyObject?
    let queue: DispatchQueue = DispatchQueue(label: "com.embrace.crashlytics_wrapper")

    @ThreadSafe private(set) var retryCount: Int = 0

    convenience init(maxRetryCount: Int = 5, retryDelay: Double = 1.0) {
        self.init(options: Options(
            className: "FIRCrashlytics",
            singletonSelector: NSSelectorFromString("crashlytics"),
            setValueSelector: NSSelectorFromString("setCustomValue:forKey:"),
            maxRetryCount: maxRetryCount,
            retryDelay: retryDelay
        ))
    }

    init(options: CrashlyticsWrapper.Options) {
        self.options = options

        self.queue.async { [weak self] in
            self?.findInstance()
        }
    }

    var currentSessionId: String? {
        didSet {
            updateSessionId()
        }
    }

    var sdkVersion: String? {
        didSet {
            updateSDKVersion()
        }
    }

    private func findInstance() {
        self.queue.asyncAfter(deadline: .now() + options.retryDelay) { [weak self] in
            self?.findCrashlyticsInstance()
        }
    }

    private func findCrashlyticsInstance() {
        guard retryCount < options.maxRetryCount && instance == nil else {
            return
        }

        guard let crashlyticsClass = NSClassFromString(options.className) as? NSObject.Type else {
            retryCount = options.maxRetryCount
            return
        }

        let selector = options.singletonSelector
        if crashlyticsClass.responds(to: selector) {
            let value = crashlyticsClass.perform(selector)
            instance = value?.takeUnretainedValue()

            updateSessionId()
            updateSDKVersion()
        }

        retryCount += 1

        if instance == nil {
            self.findInstance()
        }
    }

    private func setCustomValue(key: String, value: String) {
        guard let instance = instance else {
            return
        }

        let selector = options.setValueSelector
        if instance.responds(to: selector) {
            _ = instance.perform(selector, with: value, with: key)
        }
    }

    private func updateSessionId() {
        guard let currentSessionId = currentSessionId else {
            return
        }

        setCustomValue(key: "emb-sid", value: currentSessionId)
    }

    private func updateSDKVersion() {
        guard let sdkVersion = sdkVersion else {
            return
        }

        setCustomValue(key: "emb-sdk", value: sdkVersion)
    }
}
