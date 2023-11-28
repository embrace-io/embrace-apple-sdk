//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI

import EmbraceIO

@main
struct BrandGameApp: App {

    @State var settings: AppSettings = AppSettings()

    init() {
        do{
            try Embrace.setup(
                options: embraceOptions)
            try Embrace.client?.start()
        }catch let e{
            print("Error starting embrace \(e.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.settings, settings)
        }
    }
}
