//
//  NetworkingTestBodyPropertyView.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct NetworkingTestBodyPropertyView: View {
    var addBodyPropertyAction: (String, String) -> Void
    @State private var propertyKey: String = ""
    @State private var propertyValue: String = ""

    var body: some View {
        VStack {
            VStack {
                HStack {
                    Spacer()
                    Text("Key")
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    TextField("A key", text: $propertyKey)
                        .font(.embraceFont(size: 18))
                        .foregroundStyle(.embraceSilver)
                        .padding([.leading, .trailing,], 5)
                        .textFieldStyle(RoundedStyle())
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .accessibilityIdentifier("NetworkingTestBody_Key")
                }
                HStack {
                    Spacer()
                    Text("Value")
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    TextField("A value", text: $propertyValue)
                        .font(.embraceFont(size: 18))
                        .foregroundStyle(.embraceSilver)
                        .padding([.leading, .trailing,], 5)
                        .textFieldStyle(RoundedStyle())
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("NetworkingTestBody_Value")
                }
                Button {
                    addBodyPropertyAction(propertyKey, propertyValue)
                    propertyKey = ""
                    propertyValue = ""
                } label: {
                    Text("Insert Body Property")
                        .frame(height: 40)
                }
                .accessibilityIdentifier("NetworkingTestBody_Insert_Button")
            }
        }
    }
}

#Preview {
    return NetworkingTestBodyPropertyView { key, value in
        print("Added key: \(key) - valud: \(value)")
    }
}
