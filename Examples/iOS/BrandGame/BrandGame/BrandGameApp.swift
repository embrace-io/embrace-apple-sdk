//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI

import EmbraceIO

@main
struct BrandGameApp: App {

    init() {
        Embrace.setup(
            options: embraceOptions,
            collectors: [])
        Embrace.client?.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
