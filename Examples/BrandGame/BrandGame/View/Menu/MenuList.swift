//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI

struct MenuList: View {

    @Environment(\.settings) var appSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section("Metadata") {
               NavigationLink(destination: LazyView(UserInfo())) {
                   Text("User Information")
               }
               .contentShape(Rectangle())
            }

            Section("Mini-Games") {
                ForEach(Minigame.allCases, id: \.self) { game in
                    HStack {
                        Text(game.rawValue)
                        Spacer()
                        if appSettings.selectedMinigame == game {
                            Image(systemName: "checkmark")
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appSettings.selectedMinigame = game
                        dismiss()
                    }
                }
            }

            Section("Stress Tests") {
                NavigationLink("Network Requests", destination: NetworkStressTest())
                    .contentShape(Rectangle())

                NavigationLink("Logging", destination: LoggingView()).contentShape(Rectangle())

                NavigationLink("Crash Examples", destination: CrashExampleTest())
                    .contentShape(Rectangle())
            }
        }
        .background(.black)
    }
}

#Preview {
    MenuList()
}
