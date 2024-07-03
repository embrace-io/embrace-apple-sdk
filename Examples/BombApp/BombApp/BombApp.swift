//
//  BombApp.swift
//  BombApp
//
//  Created by Ariel Demarco on 02/07/2024.
//

import SwiftUI

@main
struct BombApp: App {
    @UIApplicationDelegateAdaptor(BombAppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                BombView()
            }
        }
    }
}
