//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Firebase
import EmbraceIO
import UIKit

class BombAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        FirebaseApp.configure()

        do {
            try Embrace
                .setup(options: embraceOptions)
                .start()
        } catch let exception {
            print("Couldn't initialize embrace: \(exception.localizedDescription)")
        }
        return true
    }
}
