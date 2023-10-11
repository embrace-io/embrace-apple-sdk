//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI

struct ContentView: View {

    @State var isShowingMenu: Bool = false

    var body: some View {
        ZStack {
            Color.embraceLead

            InteractiveBracketLogo()
                .padding()
        }
        .gesture(
            TapGesture(count: 3)
                .onEnded { _ in
                    print("tap \(Date())")
                    isShowingMenu = true
                })
        .ignoresSafeArea(.all)
        .sheet(isPresented: $isShowingMenu) {
            MainMenu()
        }
    }
}

#Preview {
    ContentView()
}
