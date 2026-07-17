//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Combine
import EmbraceIO
import SwiftUI

struct UserInfo: View {

    class EmbraceUser: ObservableObject {
        @Published var identifier: String = ""

        private var cancellables = Set<AnyCancellable>()

        func listen() {
            cancellables.removeAll()

            $identifier
                .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
                .sink { output in
                    EmbraceIO.shared.userIdentifier = output.isEmpty ? nil : output
                }
                .store(in: &cancellables)
        }

        func refresh() {
            identifier = EmbraceIO.shared.userIdentifier ?? ""
        }

        func clearProperties() {
            EmbraceIO.shared.userIdentifier = nil
            identifier.removeAll()
        }

        func clearPersonas() {
            EmbraceIO.shared.removeAllPersonas(lifespans: [.session, .process, .permanent])
            objectWillChange.send()
        }

        func toggle(persona: String, lifespan: MetadataLifespan) {
            if hasPersona(persona) {
                EmbraceIO.shared.removePersona(persona, lifespan: lifespan)
            } else {
                EmbraceIO.shared.addPersona(persona, lifespan: lifespan)
            }

            objectWillChange.send()
        }

        func hasPersona(_ persona: String) -> Bool {
            let group = DispatchGroup()
            var contains = false

            group.enter()
            EmbraceIO.shared.getCurrentPersonas { tags in
                contains = tags.contains(persona)
                group.leave()
            }
            group.wait()

            return contains
        }
    }

    // Retrieve scenePhase so we can see session metadata removed when app is foregrounded.
    @Environment(\.scenePhase) var scenePhase

    @StateObject var user = EmbraceUser()

    var body: some View {
        Form {
            Section(header: Text("Properties")) {
                TextField("Identifier", text: $user.identifier)

                Button("Clear All") {
                    user.clearProperties()
                }
            }

            Section(header: Text("Personas - Session")) {
                PersonaGrid(lifespan: .session, user: user)

                Button("Clear All") {
                    user.clearPersonas()
                }
            }
        }
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .onAppear {
            user.refresh()
            user.listen()
        }.onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                user.refresh()
            }
        }.navigationTitle("User Information")

    }
}

extension UserInfo {
    static var quickPersonas: [String] {
        ["free", "preview", "subscriber", "payer", "guest", "pro", "mvp", "vip"]
    }

    static var personaColors: [Color] {
        [
            Color.embraceLead,
            Color.embracePink,
            Color.embracePurple,
            Color.embraceSilver
        ]
    }
}

#Preview {
    UserInfo()
}
