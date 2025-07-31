//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCore
import SwiftUI

struct CrashExampleTest: View {
    @State private var selectedExample: ExampleCrash = .fatalError
    @State private var showAddCrashInfo: Bool = false

    var body: some View {
        Form {
            Section("Crash Type") {
                List(ExampleCrash.allCases, id: \.self) { crashExample in
                    HStack {
                        Text(title(for: crashExample))
                        Spacer()
                        if crashExample == selectedExample {
                            Image(systemName: "checkmark")
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedExample = crashExample
                    }
                }
            }

            Section("Actions") {
                Button {
                    showAddCrashInfo = true
                } label: {
                    Text("Add Extra Info")
                }
            }

            Section {
                Button {
                    Embrace.client?.crash(type: selectedExample)
                } label: {
                    Text("Submit")
                }
            }

            Text("Submitting this form will cause the app to crash")
                .foregroundStyle(Color.secondary)
                .listRowBackground(Color.clear)
        }.sheet(
            isPresented: $showAddCrashInfo,
            content: {
                NavigationStack {
                    AddCrashInfoView()
                }.presentationDetents([.medium])
            }
        )
        .navigationTitle("Crash Examples")
    }

    func title(for example: ExampleCrash) -> String {
        switch example {
        case .fatalError: "Swift Fatal Error"
        case .unwrapOptional: "Force Unwrap Optional"
        case .indexOutOfBounds: "Array Index Out of Bounds"
        }
    }
}

#Preview {
    CrashExampleTest()
}
