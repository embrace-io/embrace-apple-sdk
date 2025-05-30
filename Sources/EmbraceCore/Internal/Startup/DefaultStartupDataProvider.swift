//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if !EMBRACE_COCOAPOD_BUILDING_SDK
@_implementationOnly import EmbraceObjCUtilsInternal
#endif

class DefaultStartupDataProvider: StartupDataProvider {

    let buildUUIDKey = "emb.buildUUID"
    let bootTimeKey = "emb.bootTime"

    let startupType: StartupType

    var onFirstFrameTimeSet: ((Date) -> Void)?
    var onAppDidFinishLaunchingEndTimeSet: ((Date) -> Void)?

    init() {
        guard let newBuildUUID = EMBDevice.buildUUID?.uuidString else {
            startupType = .cold
            return
        }

        // fetch old values
        let oldBuildUUID = UserDefaults.standard.string(forKey: buildUUIDKey)
        let oldBootTime = UserDefaults.standard.double(forKey: bootTimeKey)

        let newBootTime = EMBDevice.bootTime.doubleValue

        // save new values
        UserDefaults.standard.setValue(newBuildUUID, forKey: buildUUIDKey)
        UserDefaults.standard.setValue(newBootTime, forKey: bootTimeKey)

        // compare to determine if its a cold or warm startup
        if (oldBuildUUID == nil || oldBootTime == 0) ||
           (oldBuildUUID != newBuildUUID && oldBootTime != newBootTime) {
            startupType = .cold
        } else {
            startupType = .warm
        }

        // set callbacks
        EMBStartupTracker.shared().onFirstFrameTimeSet = { [weak self] date in
            self?.onFirstFrameTimeSet?(date)
        }

        EMBStartupTracker.shared().onAppDidFinishLaunchingEndTimeSet = { [weak self] date in
            self?.onAppDidFinishLaunchingEndTimeSet?(date)
        }
    }

    var isPrewarm: Bool {
        ProcessInfo.processInfo.environment["ActivePrewarm"] == "1"
    }

    var processStartTime: Date? {
        ProcessMetadata.startTime
    }

    var constructorClosestToMainTime: Date {
        EMBStartupTracker.shared().constructorClosestToMainTime
    }

    var firstFrameTime: Date? {
        EMBStartupTracker.shared().firstFrameTime
    }

    var appDidFinishLaunchingEndTime: Date? {
        EMBStartupTracker.shared().appDidFinishLaunchingEndTime
    }

    var sdkSetupStartTime: Date? {
        EMBStartupTracker.shared().sdkSetupStartTime
    }

    var sdkSetupEndTime: Date? {
        EMBStartupTracker.shared().sdkSetupEndTime
    }

    var sdkStartStartTime: Date? {
        EMBStartupTracker.shared().sdkStartStartTime
    }

    var sdkStartEndTime: Date? {
        EMBStartupTracker.shared().sdkStartEndTime
    }
}
