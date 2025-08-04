//
//  View.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

extension View {
    func navigationBarModifier(backgroundColor: UIColor = .embraceLead, foregroundColor: UIColor = .embraceYellow)
        -> some View
    {
        self.modifier(NavigationBarModifier(backgroundColor: backgroundColor, foregroundColor: foregroundColor))
    }
}

/// Sigh...
struct NavigationBarModifier: ViewModifier {
    init(backgroundColor: UIColor = .embraceLead, foregroundColor: UIColor = .embraceYellow) {
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.titleTextAttributes = [
            .foregroundColor: foregroundColor, .font: UIFont.systemFont(ofSize: 20, weight: .bold)
        ]
        navBarAppearance.largeTitleTextAttributes = [.foregroundColor: foregroundColor]
        navBarAppearance.backgroundColor = backgroundColor
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
    }
    func body(content: Content) -> some View {
        content
    }
}
