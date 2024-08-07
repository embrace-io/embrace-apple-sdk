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
                NavigationLink(destination: SessionAttributesView()) {
                    Text("Session Attributes")
                }
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

            Section("Tests") {
                NavigationLink(
                    "Memory Pressure Simulator",
                    destination: MemoryPressureSimulatorView()
                )
                NavigationLink(
                    "Network Requests",
                    destination: NetworkStressTest()
                )
                NavigationLink(
                    "OpenTelemetry",
                    destination: OpenTelemetryView()
                )
                NavigationLink(
                    "WebView Usage",
                    destination: BrowserView()
                )
                NavigationLink(
                    "Logging",
                    destination: LoggingView()
                )
                NavigationLink(
                    "Crashes",
                    destination: CrashExampleTest()
                )
            }
        }
        .background(.black)
    }
}

#Preview {
    MenuList()
}
