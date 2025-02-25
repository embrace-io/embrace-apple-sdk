//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI

import EmbraceIO
import EmbraceCommon

@main
struct BrandGameApp: App {

    @State var settings: AppSettings = AppSettings()

    init() {
        print(HelloWorld_iosKt.kmpString())
        do {
            try Embrace
                .setup(options: embraceOptions)
                .start()

            addGitInfoProperties()
            smokeTestIfNecessary()
        } catch let exception {
            print("Error starting Embrace \(exception.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.settings, settings)
        }
    }
}
