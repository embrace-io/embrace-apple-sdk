//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI

struct AttributesView: View {
    @Binding var key: String
    @Binding var value: String
    @Binding var attributes: [String: String]

    var body: some View {
        Group {
            Text("Attributes")
                .font(.title3)
                .bold()
            HStack {
                TextField("Key", text: $key)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Value", text: $value)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button(action: {
                    attributes[key] = value
                    key = ""
                    value = ""
                }, label: {
                    Image(systemName: "plus.circle.fill")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .foregroundColor(.blue)
                })
                .disabled(key.isEmpty || value.isEmpty)
            }

            GeometryReader { proxy in
                ScrollView {
                    LazyVStack {
                        if !attributes.isEmpty {
                            HStack {
                                Text("Key")
                                    .bold()
                                    .frame(maxWidth: calculateCellWidth(basedOnProxy: proxy))
                                Text("Value")
                                    .bold()
                                    .frame(maxWidth: calculateCellWidth(basedOnProxy: proxy))
                            }.padding(.bottom, 8)
                        }
                        ForEach(attributes.keys.sorted(), id: \.self) { key in
                            HStack {
                                Text(key)
                                    .frame(maxWidth: calculateCellWidth(basedOnProxy: proxy))
                                    .lineLimit(1)
                                Text(attributes[key] ?? "")
                                    .frame(maxWidth: calculateCellWidth(basedOnProxy: proxy))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.top)
                }
                .background(Color.white)
                .cornerRadius(10)
            }
        }.padding()
    }

    private func calculateCellWidth(basedOnProxy geometryProxy: GeometryProxy) -> Double {
        let fulldWidth = geometryProxy.size.width
        let insets = geometryProxy.safeAreaInsets.leading + geometryProxy.safeAreaInsets.trailing
        let availableSpace = fulldWidth - insets
        return availableSpace / 2.0
    }
}

#Preview {
    AttributesView(key: .constant("hello"), value: .constant("world"), attributes: .constant(["One": "attr"]))
}
