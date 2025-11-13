//
//  LoginScreen.swift
//  Embrace-tvOS-TestApp
//
//

import EmbraceCore
import EmbraceMacros
import SwiftUI

@EmbraceTrace
struct LoginScreen: View {
    @Environment(AppNavigator.self) var navigator
    @State var username: String = ""
    @State var userId: String = ""
    @State var userEmail: String = ""

    var body: some View {
        VStack(alignment: .center) {
            EmbraceLogo()

            Text("tvOS Test App")
                .font(.embraceFont(size: 60))
                .foregroundStyle(.embraceSteel)

            EmbraceTextField(
                title: "User Name",
                output: $username,
                submitLabel: .continue,
                frameWidth: 500)

            EmbraceTextField(
                title: "User Email",
                output: $userEmail,
                submitLabel: .continue,
                frameWidth: 500)

            EmbraceTextField(
                title: "User Id",
                output: $userId,
                submitLabel: .continue,
                frameWidth: 500)

            EmbraceButton(title: "\"Login\"", accessibilityLabel: "Login Button") {
                Embrace.client?.metadata.userName = username
                Embrace.client?.metadata.userIdentifier = userId
                Embrace.client?.metadata.userEmail = userEmail
                navigator.backToRoot()
            }

            EmbraceButton(title: "Skip", accessibilityLabel: "Skip Login Button") {
                Embrace.client?.metadata.userName = nil
                Embrace.client?.metadata.userIdentifier = nil
                Embrace.client?.metadata.userEmail = nil
                navigator.backToRoot()
            }
        }
        .padding()
    }
}

#Preview {
    LoginScreen()
        .environment(AppNavigator())
}
