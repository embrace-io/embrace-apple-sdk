//
//  MainScreen.swift
//  Embrace-tvOS-TestApp
//
//

import EmbraceMacros
import SwiftUI

@EmbraceTrace
struct MainScreen: View {
    @Environment(AppNavigator.self) var navigator
    @State private var presentedLogin = false

    var body: some View {
        VStack(alignment: .center) {
            EmbraceLogo()
                .padding(.bottom, 150)
            ScrollView {
                ForEach(MainScreenDataModel.allCases, id: \.rawValue) { option in
                    EmbraceButton(title: option.title, accessibilityLabel: option.identifier) {
                        navigator.path.append(option)
                    }
                    .padding(.bottom, 10)
                }
                .padding([.leading, .trailing, .top, .bottom], 50)
            }
        }
        .padding()
        .navigationDestination(for: MainScreenDataModel.self) {
            $0.screen
        }
        .onAppear {
            if !presentedLogin {
                navigator.navigate(to: .login)
                presentedLogin = true
            }
        }
    }
}

#Preview {
    MainScreen()
        .environment(AppNavigator())
}
