//
//  LoginScreen.swift
//  Embrace-tvOS-TestApp
//
//

import EmbraceCore
import EmbraceMacros
import SwiftUI

struct LoginScreen: View {
    @State var username: String = ""
    @State var userId: String = ""
    @State var userEmail: String = ""

    var body: some View {
        VStack(alignment: .center) {
            HStack {
                Image(.embraceLogo)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100)
                    .colorMultiply(.embraceYellow)
                Text("embrace")
                    .font(.embraceFont(size: 80))
                    .foregroundStyle(.embraceYellow)
            }

            Text("tvOS Test App")
                .font(.embraceFont(size: 60))
                .foregroundStyle(.embraceSteel)

            TextField("UserName", text: $username)
                .font(.embraceFontLight(size: 30))
                .submitLabel(.continue)
                .frame(width: 500)

            TextField("User email", text: $userEmail)
                .font(.embraceFontLight(size: 30))
                .submitLabel(.continue)
                .frame(width: 500)

            TextField("User id", text: $userId)
                .font(.embraceFontLight(size: 30))
                .submitLabel(.continue)
                .frame(width: 500)

            Button {
                Embrace.client?.metadata.userName = username
                Embrace.client?.metadata.userIdentifier = userId
                Embrace.client?.metadata.userEmail = userEmail
            } label: {
                Text("\"Login\"")
                    .font(.embraceFont(size: 30))
                    .foregroundStyle(.embraceSilver)
            }.accessibilityLabel("Login Button")

            Button {
                Embrace.client?.metadata.userName = nil
                Embrace.client?.metadata.userIdentifier = nil
                Embrace.client?.metadata.userEmail = nil
            } label: {
                Text("Skip")
                    .font(.embraceFont(size: 30))
                    .foregroundStyle(.embraceSilver)
            }.accessibilityLabel("Skip Login Button")
        }
        .padding()
        .embraceTrace("Login View")
    }
}

#Preview {
    LoginScreen()
}
