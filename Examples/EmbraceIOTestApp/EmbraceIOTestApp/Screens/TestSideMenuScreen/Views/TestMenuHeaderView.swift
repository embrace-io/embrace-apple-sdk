//
//  TestMenuHeaderView.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct TestMenuHeaderView: View {
    var body: some View {
        VStack {
            Image("embrace-logo")
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(.embraceYellow)
                .aspectRatio(contentMode: .fit)
                .shadow(color: .embraceYellow, radius: 3)
        }
        .frame(width: 80)
    }
}


#Preview {
    return TestMenuHeaderView()
}
