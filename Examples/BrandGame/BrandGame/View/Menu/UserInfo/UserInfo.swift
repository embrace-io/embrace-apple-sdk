//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Combine
import SwiftUI

#if COCOAPODS
    import EmbraceIO
#else
    import EmbraceCore
#endif

struct UserInfo: View {

    class EmbraceUser: ObservableObject {
        @Published var username: String = ""
        @Published var identifier: String = ""
        @Published var email: String = ""

        private var cancellables = Set<AnyCancellable>()

        func listen() {
            cancellables.removeAll()

            $username
                .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
                .sink { output in
                    Embrace.client?.metadata.userName = output.isEmpty ? nil : output
                }
                .store(in: &cancellables)

            $identifier
                .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
                .sink { output in
                    Embrace.client?.metadata.userIdentifier = output.isEmpty ? nil : output
                }
                .store(in: &cancellables)

            $email
                .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
                .sink { output in
                    Embrace.client?.metadata.userEmail = output.isEmpty ? nil : output
                }
                .store(in: &cancellables)
        }

        func refresh() {
            guard let metadata = Embrace.client?.metadata else {
                return
            }

            username = metadata.userName ?? ""
            identifier = metadata.userIdentifier ?? ""
            email = metadata.userEmail ?? ""
        }

        func clearProperties() {
            Embrace.client?.metadata.clearUserProperties()

            // Need to clear local state as well
            username.removeAll()
            identifier.removeAll()
            email.removeAll()
        }

        func clearPersonas() {
            Embrace.client?.metadata.removeAllPersonas()
            objectWillChange.send()
        }

        func toggle(persona: PersonaTag, lifespan: MetadataLifespan) {
            if hasPersona(persona) {
                try? Embrace.client?.metadata.remove(persona: persona, lifespan: lifespan)
            } else {
                try? Embrace.client?.metadata.add(persona: persona, lifespan: lifespan)
            }

            objectWillChange.send()
        }

        func hasPersona(_ persona: PersonaTag) -> Bool {
            let group = DispatchGroup()
            var contains = false

            group.enter()
            Embrace.client?.metadata.getCurrentPersonas { tags in
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
                TextField("Username", text: $user.username)
                TextField("Identifier", text: $user.identifier)
                TextField("Email", text: $user.email)

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

    func personaGridRows(size: Int = 3) -> [[PersonaTag]] {
        let count = Self.quickPersonas.count

        return stride(from: 0, to: count, by: size).map {
            Array(Self.quickPersonas[$0..<Swift.min($0 + size, count)])
        }
    }

    func colorForPersona(persona: PersonaTag) -> Color {
        let idx = persona.rawValue.count % Self.personaColors.count
        return Self.personaColors[idx]
    }

}

extension UserInfo {
    static var quickPersonas: [PersonaTag] {
        [
            PersonaTag.free,
            PersonaTag.preview,
            PersonaTag.subscriber,
            PersonaTag.payer,
            PersonaTag.guest,
            PersonaTag.pro,
            PersonaTag.mvp,
            PersonaTag.vip
        ]
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

extension PersonaTag: Identifiable {
    public var id: String { rawValue }
}

extension PersonaTag: Hashable {}

#Preview {
    UserInfo()
}
