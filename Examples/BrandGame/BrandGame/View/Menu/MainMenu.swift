//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI

struct MainMenu: View {

    @Environment(\.dismiss) var dismiss

    private var dismissButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.down")
        }
    }
    
    func navigationView(_ content: () -> some View) -> some View {
        #if os(macOS)
        NavigationStack {
            ScrollView {
                content()
            }
        }
        #else
        NavigationStack {
            content()
        }
        #endif
    }
    var body: some View {
        navigationView {
            MenuList()
                .toolbar {
#if !os(macOS)
                    ToolbarItem(placement: .topBarLeading) {
                        dismissButton
                    }
#else
                    ToolbarItem(placement: .cancellationAction) {
                        dismissButton
                    }
#endif
                }
#if os(macOS)
                .frame(height: 500)
#endif
        }
    }
}

#Preview {
    MainMenu()
}
