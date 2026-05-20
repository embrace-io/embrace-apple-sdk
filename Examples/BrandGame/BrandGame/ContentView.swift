//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceIO
import SwiftUI

struct ContentView: View {

    @State var isShowingMenu: Bool = false

    var body: some View {
        ZStack {
            Color.embraceLead

            MinigameView()
        }
        .gesture(
            TapGesture(count: 3)
                .onEnded { _ in
                    isShowingMenu = true
                    EmbraceIO.shared.setProperty(key: "user.menu.open", value: "true", lifespan: .session)
                }
        )
        .ignoresSafeArea(.all)
        .sheet(isPresented: $isShowingMenu) {
            MainMenu()
        }
    }
}

#Preview {
    ContentView()
}
