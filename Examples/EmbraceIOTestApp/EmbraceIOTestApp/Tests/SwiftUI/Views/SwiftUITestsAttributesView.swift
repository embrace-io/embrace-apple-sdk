//
//  SwiftUITestsAttributesView.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct SwiftUITestsAttributesView: View {
    var addAttribute: (String, String) -> Void
    @State private var key: String = ""
    @State private var value: String = ""

    var body: some View {
        VStack {
            VStack {
                HStack {
                    Spacer()
                    Text("Key")
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .font(.embraceFont(size: 15))
                        .foregroundStyle(.embraceSilver)
                    TextField("A key", text: $key)
                        .font(.embraceFont(size: 18))
                        .foregroundStyle(.embraceSilver)
                        .padding([.leading, .trailing], 5)
                        .textFieldStyle(RoundedStyle())
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .accessibilityIdentifier("SwiftUITestsAttributesView_Key")
                }
                HStack {
                    Spacer()
                    Text("Value")
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .font(.embraceFont(size: 15))
                        .foregroundStyle(.embraceSilver)
                    TextField("A value", text: $value)
                        .font(.embraceFont(size: 18))
                        .foregroundStyle(.embraceSilver)
                        .padding([.leading, .trailing], 5)
                        .textFieldStyle(RoundedStyle())
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("SwiftUITestsAttributesView_Value")
                }
                Button {
                    addAttribute(key, value)
                    key = ""
                    value = ""
                } label: {
                    Text("Add Attribute")
                        .frame(height: 60)
                        .font(.embraceFont(size: 15))
                }
                .accessibilityIdentifier("SwiftUITestsAttributesView_Add_Button")
            }
        }
    }
}

#Preview {
    return SwiftUITestsAttributesView { key, value in
        print("Added key: \(key) - value: \(value)")
    }
}
