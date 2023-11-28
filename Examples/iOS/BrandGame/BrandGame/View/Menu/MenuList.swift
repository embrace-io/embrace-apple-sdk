//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI

struct MenuList: View {

    @Environment(\.settings) var appSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section("Mini-Games") {
                ForEach(Minigame.allCases, id: \.self) { game in
                    HStack {
                        Text(game.rawValue)
                        Spacer()
                        if appSettings.selectedMinigame == game {
                            Image(systemName: "checkmark")
                        }
                    }
                    .onTapGesture {
                        appSettings.selectedMinigame = game
                        dismiss()
                    }
                }
            }
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
