//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if HAS_CRASHLYTICS
import Firebase
#endif
import EmbraceIO
import UIKit

class BombAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        #if HAS_CRASHLYTICS
        FirebaseApp.configure()
        #endif
        do {
            try Embrace
                .setup(options: embraceOptions)
                .start()
        } catch let exception {
            print("Couldn't initialize embrace: \(exception.localizedDescription)")
        }
        MetricKitSubscriber.start()
        return true
    }
}
