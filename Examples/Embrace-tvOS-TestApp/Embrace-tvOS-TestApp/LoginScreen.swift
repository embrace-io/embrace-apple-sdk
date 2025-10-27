//
//  LoginScreen.swift
//  Embrace-tvOS-TestApp
//
//  Created by Fernando Draghi on 14/10/2025.
//

import SwiftUI
import EmbraceCore

struct LoginScreen: View {
    @State var username: String = ""
    @State var userId: String = ""
    @State var userEmail: String = ""

    var body: some View {
        VStack {
            HStack {
                Text("User")
                    .frame(width: 500, alignment: .trailing)
                TextField("UserName", text: $username)
                    .submitLabel(.continue)
                    .frame(width: 500)
            }
            HStack {
                Text("User Email")
                    .frame(width: 500, alignment: .trailing)
                TextField("User email", text: $userEmail)
                    .submitLabel(.continue)
                    .frame(width: 500)
            }
            HStack {
                Text("User Id")
                    .frame(width: 500, alignment: .trailing)
                TextField("User id", text: $userId)
                    .submitLabel(.continue)
                    .frame(width: 500)
            }
            
            
            Button {
                Embrace.client?.metadata.userName = username
                Embrace.client?.metadata.userIdentifier = userId
                Embrace.client?.metadata.userEmail = userEmail
            } label: {
                Text("\"Login\"")
            }
            
            Button {
                Embrace.client?.metadata.userName = nil
                Embrace.client?.metadata.userIdentifier = nil
                Embrace.client?.metadata.userEmail = nil
            } label: {
                Text("Skip")
            }
        }
        .padding()
    }
}

#Preview {
    LoginScreen()
}
