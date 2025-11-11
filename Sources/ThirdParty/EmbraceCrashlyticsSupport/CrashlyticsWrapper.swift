//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

class CrashlyticsWrapper: @unchecked Sendable {

    class Options {
        let className: String
        let singletonSelector: Selector
        let setValueSelector: Selector

        let maxRetryCount: Int
        let retryDelay: Double

        let instanceFoundBlock: (() -> Void)?

        init(
            className: String,
            singletonSelector: Selector,
            setValueSelector: Selector,
            maxRetryCount: Int,
            retryDelay: Double,
            instanceFoundBlock: (() -> Void)? = nil
        ) {
            self.className = className
            self.singletonSelector = singletonSelector
            self.setValueSelector = setValueSelector
            self.maxRetryCount = maxRetryCount
            self.retryDelay = retryDelay
            self.instanceFoundBlock = instanceFoundBlock
        }
    }

    struct MutableData {
        var options: CrashlyticsWrapper.Options
        var instance: AnyObject?
        var customValues: [String: String] = [:]
        var retryCount: Int = 0
    }
    private var data: EmbraceMutex<MutableData>
    private var options: CrashlyticsWrapper.Options {
        data.withLock { $0.options }
    }
    public private(set) var instance: AnyObject? {
        get {
            data.withLock { $0.instance }
        }
        set {
            data.withLock { $0.instance = newValue }
        }
    }
    private var retryCount: Int {
        get {
            data.withLock { $0.retryCount }
        }
        set {
            data.withLock { $0.retryCount = newValue }
        }
    }
    private var customValues: [String: String] {
        get {
            data.withLock { $0.customValues }
        }
        set {
            data.withLock { $0.customValues = newValue }
        }
    }

    let queue: DispatchQueue = DispatchQueue(label: "com.embrace.crashlytics_wrapper")

    convenience init(maxRetryCount: Int = 5, retryDelay: Double = 1.0) {
        self.init(
            options: Options(
                className: "FIRCrashlytics",
                singletonSelector: NSSelectorFromString("crashlytics"),
                setValueSelector: NSSelectorFromString("setCustomValue:forKey:"),
                maxRetryCount: maxRetryCount,
                retryDelay: retryDelay
            ))
    }

    init(options: CrashlyticsWrapper.Options) {
        data = EmbraceMutex(MutableData(options: options))

        self.queue.async { [weak self] in
            self?.findInstance(after: 0)
        }
    }

    private func findInstance(after delay: Double) {
        self.queue.asyncAfter(deadline: .now() + delay) { [weak self] in
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

            options.instanceFoundBlock?()

            customValues.forEach { key, value in
                setCustomValue(key: key, value: value)
            }
        }

        retryCount += 1

        if instance == nil {
            self.findInstance(after: options.retryDelay)
        }
    }

    private func _customValueOnCrashlytics(key: String, value: String) {
        guard let instance = instance else {
            return
        }

        let selector = options.setValueSelector
        if instance.responds(to: selector) {
            _ = instance.perform(selector, with: value, with: key)
        }
    }

    func setCustomValue(key: String, value: String) {
        customValues[key] = value
        _customValueOnCrashlytics(key: key, value: value)
    }

    func getCustomValue(key: String) -> String? {
        customValues[key]
    }
}
