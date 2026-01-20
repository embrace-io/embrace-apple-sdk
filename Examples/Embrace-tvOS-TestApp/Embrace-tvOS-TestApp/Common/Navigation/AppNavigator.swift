//
//  AppNavigator.swift
//  tvosTestApp
//
//

import SwiftUI

@Observable
class AppNavigator {
    var path = NavigationPath()

    func navigate(to screen: AppScreens) {
        path.append(screen)
    }

    func backToRoot() {
        path.removeLast(path.count)
    }
}
