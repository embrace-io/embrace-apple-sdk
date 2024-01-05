//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI
import Combine
import EmbraceCore

struct UserInfo: View {

    class EmbraceUser: ObservableObject {
        @Published var username: String = Embrace.client?.user.username ?? ""
        @Published var identifier: String = Embrace.client?.user.identifier ?? ""
        @Published var email: String = Embrace.client?.user.email ?? ""

        private var cancellables = Set<AnyCancellable>()

        init() {
            $username
                .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
                .sink { output in
                    Embrace.client?.user.username = output.isEmpty ? nil : output
                }
                .store(in: &cancellables)

            $identifier
                .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
                .sink { output in
                    Embrace.client?.user.identifier = output.isEmpty ? nil : output
                }
                .store(in: &cancellables)

            $email
                .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
                .sink { output in
                    Embrace.client?.user.email = output.isEmpty ? nil : output
                }
                .store(in: &cancellables)
        }

        func clear() {
            Embrace.client?.user.clear()

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
    }
}

#Preview {
    UserInfo()
}
