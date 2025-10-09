//
//  TestHelpers.swift
//  EmbraceIOTestApp
//
//

import EmbraceObjCUtilsInternal
import Foundation
import UIKit

struct TestHelpers {

    static func resetStartupInstrumentation() {
        EMBStartupTracker.shared().resetLifecycleNotifications()
        NotificationCenter.default.post(name: UIApplication.didFinishLaunchingNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    }
}
