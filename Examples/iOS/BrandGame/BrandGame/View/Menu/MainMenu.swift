//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI

struct MainMenu: View {

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            MenuList()
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.down")
                        }
                    }
                }
        }
    }
}

#Preview {
    MainMenu()
}
