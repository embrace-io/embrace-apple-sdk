//
//  LoggingTestsLogAttributesView.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct LoggingTestsLogAttributesView: View {
    var addAttributeAction: (String, String) -> Void
    @State private var attributeKey: String = ""
    @State private var attributeValue: String = ""

    var body: some View {
        VStack {
            VStack {
                HStack {
                    Spacer()
                    Text("Key")
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    TextField("A key", text: $attributeKey)
                        .font(.embraceFont(size: 18))
                        .foregroundStyle(.embraceSilver)
                        .padding([.leading, .trailing,], 5)
                        .textFieldStyle(RoundedStyle())
                        .accessibilityIdentifier("LogTestsAttributes_Key")
                }
                HStack {
                    Spacer()
                    Text("Value")
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    TextField("A value", text: $attributeValue)
                        .font(.embraceFont(size: 18))
                        .foregroundStyle(.embraceSilver)
                        .padding([.leading, .trailing,], 5)
                        .textFieldStyle(RoundedStyle())
                        .accessibilityIdentifier("LogTestsAttributes_Value")
                }
                Button {
                    addAttributeAction(attributeKey, attributeValue)
                    attributeKey = ""
                    attributeValue = ""
                } label: {
                    Text("Insert Attribute")
                        .frame(height: 40)
                }
                .accessibilityIdentifier("LogTestsAttributes_Insert_Button")
            }
        }
    }
}

#Preview {
    return LoggingTestsLogAttributesView { key, value in
        print("Added key: \(key) - valud: \(value)")
    }
}
