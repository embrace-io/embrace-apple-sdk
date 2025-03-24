//
//  NetworkingTestMethodTypeView.swift
//  EmbraceIOTestApp
//
//

import SwiftUI
import EmbraceCommonInternal

struct NetworkingTestMethodTypeView: View {
    @Binding var requestMethod: URLRequestMethod

    var body: some View {
        Picker("", selection: $requestMethod) {
            ForEach(URLRequestMethod.allCases, id: \.self) { method in
                Text(method.text)
                    .accessibilityIdentifier(identifier(for: method))
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.bottom, 20)
    }

    private func identifier(for method: URLRequestMethod) -> String {
        switch method {
        case .get:
            return "URLRequestMethod_Get"
        case .post:
            return "URLRequestMethod_Post"
        case .put:
            return "URLRequestMethod_Put"
        case .delete:
            return "URLRequestMethod_Delete"
        }
    }
}

#Preview {
    @Previewable @State var method: URLRequestMethod = .get
    NetworkingTestMethodTypeView(requestMethod: $method)
}
