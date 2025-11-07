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
    @State private var path = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .center) {
                EmbraceLogo()
                
                Text("tvOS Test App")
                    .font(.embraceFont(size: 60))
                    .foregroundStyle(.embraceSteel)
                
                EmbraceTextField(title: "User Name",
                                 output: $username,
                                 submitLabel: .continue,
                                 frameWidth: 500)
                
                EmbraceTextField(title: "User Email",
                                 output: $userEmail,
                                 submitLabel: .continue,
                                 frameWidth: 500)
                
                EmbraceTextField(title: "User Id",
                                 output: $userId,
                                 submitLabel: .continue,
                                 frameWidth: 500)
                
                EmbraceButton(title: "\"Login\"", accessibilityLabel: "Login Button") {
                    Embrace.client?.metadata.userName = username
                    Embrace.client?.metadata.userIdentifier = userId
                    Embrace.client?.metadata.userEmail = userEmail
                    path.append("mainScreen")
                }
                
                EmbraceButton(title: "Skip", accessibilityLabel: "Skip Login Button") {
                    Embrace.client?.metadata.userName = nil
                    Embrace.client?.metadata.userIdentifier = nil
                    Embrace.client?.metadata.userEmail = nil
                    path.append("mainScreen")
                }
                
                .navigationDestination(for: String.self) {
                    switch $0 {
                    case "mainScreen":
                        MainScreen()
                    default:
                        EmptyView()
                    }
                }
            }
        }
        .padding()
        .embraceTrace("Login View")
    }
}

#Preview {
    LoginScreen()
}
