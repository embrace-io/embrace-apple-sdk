//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
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
                    do {
                        try Embrace.client?.appendCrashInfo(key: key, value: value)
                        dismiss()
                    } catch let exception {
                        print(exception.localizedDescription)
                    }
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
