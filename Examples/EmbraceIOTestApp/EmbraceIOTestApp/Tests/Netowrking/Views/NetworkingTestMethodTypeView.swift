//
//  NetworkingTestMethodTypeView.swift
//  EmbraceIOTestApp
//
//

import EmbraceCommonInternal
import SwiftUI

struct NetworkingTestMethodTypeView: View {
    @Binding var requestMethod: URLRequestMethod

    var body: some View {
        Picker("", selection: $requestMethod) {
            ForEach(URLRequestMethod.allCases, id: \.self) { method in
                Text(method.description)
                    .accessibilityIdentifier(method.identifier)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.bottom, 20)
    }
}

#Preview {
    @Previewable @State var method: URLRequestMethod = .get
    return NetworkingTestMethodTypeView(requestMethod: $method)
}
