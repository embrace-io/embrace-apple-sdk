//
//  SwiftUITestsAttributesView.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct SwiftUITestsAttributesView: View {
    let keyIdentifier: String
    let valueIdentifier: String
    let addIdentifier: String
    var addAttribute: (String, String) -> Void
    @State private var key: String = ""
    @State private var value: String = ""

    init(keyIdentifier: String? = nil, valueIdentifier: String? = nil, addIdentifier: String? = nil, addAttribute: @escaping (String, String) -> Void) {
        self.keyIdentifier = keyIdentifier ?? UUID().uuidString
        self.valueIdentifier = valueIdentifier ?? UUID().uuidString
        self.addIdentifier = addIdentifier ?? UUID().uuidString
        self.addAttribute = addAttribute
    }
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
                        .accessibilityIdentifier(keyIdentifier)
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
                        .accessibilityIdentifier(valueIdentifier)
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
                .accessibilityIdentifier(addIdentifier)
            }
        }
    }
}

#Preview {
    SwiftUITestsAttributesView { key, value in
        print("Added key: \(key) - value: \(value)")
    }
}
