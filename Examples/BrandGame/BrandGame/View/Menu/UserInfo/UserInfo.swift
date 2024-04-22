//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI
import Combine
import EmbraceCore

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

        func clear() {
            Embrace.client?.metadata.clearUserProperties()

            // Need to clear local state as well
            username.removeAll()
            identifier.removeAll()
            email.removeAll()
        }
    }

    @Environment(\.dismiss) private var dismiss

    @ObservedObject var user = EmbraceUser()

    var body: some View {
        Form {
            Section {
                TextField("Username", text: $user.username)
                TextField("Identifier", text: $user.identifier)
                TextField("Email", text: $user.email)
            }

            Section {
                Button("Clear All") {
                    user.clear()
                }
            }
        }
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .onAppear {
            user.refresh()
            user.listen()
        }
    }
}

#Preview {
    UserInfo()
}
