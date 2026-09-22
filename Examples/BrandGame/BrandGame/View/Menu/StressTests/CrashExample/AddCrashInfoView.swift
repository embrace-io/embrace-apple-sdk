//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceIO
import SwiftUI

struct AddCrashInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var key: String = ""
    @State private var value: String = ""

    var body: some View {
        Form {
            Section("Fields") {
                NoSpacesTextField("Key", text: $key)
                NoSpacesTextField("Value", text: $value)
            }
            Section("Actions") {
                Button("Add") {
                    EmbraceIO.shared.appendCrashInfo(key: key, value: value)
                    dismiss()
                }.disabled(key.isEmpty || value.isEmpty)
                Button("Clear Fields") {
                    key = ""
                    value = ""
                }
                Button("Cancel", role: .destructive) {
                    dismiss()
                }
            }
        }.navigationTitle("Add Crash Info")
    }
}

#Preview {
    AddCrashInfoView()
}
