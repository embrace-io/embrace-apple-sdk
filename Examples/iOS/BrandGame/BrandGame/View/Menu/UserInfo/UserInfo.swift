//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI
import EmbraceCore

struct UserInfo: View {

    @Environment(\.dismiss) private var dismiss

    @State var username: String = Embrace.client?.user.username ?? ""
    @State var identifier: String = Embrace.client?.user.identifier ?? ""
    @State var email: String = Embrace.client?.user.email ?? ""

    var body: some View {
        Form {
            Section {
                TextField("Username", text: $username)
                TextField("Identifier", text: $identifier)
                TextField("Email", text: $email)
            }

            Section {
                Button("Clear All") {
                    Embrace.client?.user.clear()

                    // Need to clear local state as well
                    username = ""
                    identifier = ""
                    email = ""
                }
            }
        }
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .onChange(of: username) { _, value in
            Embrace.client?.user.username = value.isEmpty ? nil : value
        }
        .onChange(of: identifier) { _, value in
            Embrace.client?.user.identifier = value.isEmpty ? nil : value
        }
        .onChange(of: email) { _, value in
            Embrace.client?.user.email = value.isEmpty ? nil : value
        }
    }
}

#Preview {
    UserInfo()
}
