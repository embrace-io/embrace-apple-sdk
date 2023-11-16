//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI

struct MenuList: View {
    var body: some View {
        List {
            Section("Stress Tests") {
                NavigationLink("Network Requests", destination: NetworkStressTest())
                NavigationLink("Crash Examples", destination: CrashExampleTest())
            }
        }.background(.black)
    }
}

#Preview {
    MenuList()
}
