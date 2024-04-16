//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI

struct NetworkRequestBuilder: View {
    @StateObject var model = Request()
    @State private var selectedMethod = "POST"
    @State private var urlString = "https://httpbin.org/anything?status_code=200"
    @State private var requestBody = "{\"sessionId\": \"S0M3-B34T1FUL-UU1D\", \"randomInteger\": 10}"
    let methods = ["GET", "POST", "PUT", "DELETE"]

    var body: some View {
        VStack {
            TextField("URL", text: $urlString)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            Picker("Method", selection: $selectedMethod) {
                ForEach(methods, id: \.self) {
                    Text($0)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)

            if enableEditor() {
                TextEditor(text: $requestBody)
                    .border(Color.gray, width: 1)
                    .font(.title3)
                    .padding()
            }

            Spacer()
            HStack {
                Button {
                    model.executeRequest(urlString: urlString, httpMethod: selectedMethod, requestBody: getBody())
                } label: {
                    Text(model.requestResult.isEmpty ? "Execute" : "Re-run")
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .font(.title3)
                        .bold()
                }
                .buttonStyle(.borderedProminent)

                if !model.requestResult.isEmpty {
                    NavigationLink(destination: RequestResponseDetail(information: model.requestResult)) {
                        Text("Show Result")
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .font(.title3)
                            .bold()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }.padding()
        }
        .navigationTitle("Execute Request")
    }

    private func getBody() -> String? {
        if selectedMethod == "GET" {
            return nil
        }
        return requestBody
    }

    private func enableEditor() -> Bool {
        selectedMethod != "GET"
    }
}

#Preview {
    NavigationStack {
        NetworkRequestBuilder()
    }
}
