//
//  NetworkingTestUIComponent.swift
//  EmbraceIOTestApp
//
//

import EmbraceIO
import SwiftUI

struct NetworkingTestUIComponent: View {
    @Environment(DataCollector.self) private var dataCollector
    private var spanExporter: TestSpanExporter {
        dataCollector.spanExporter
    }
    @State var dataModel: any TestScreenDataModel
    @State private var viewModel: NetworkingTestViewModel

    init(dataModel: any TestScreenDataModel) {
        self.dataModel = dataModel
        viewModel = .init(dataModel: dataModel)
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Request URL")
                .font(.embraceFont(size: 15))
                .foregroundStyle(.embraceSteel)
                .padding([.leading, .bottom], 5)
            TextField("", text: $viewModel.testURL)
                .font(.embraceFont(size: 18))
                .foregroundStyle(.embraceSilver)
                .padding([.leading, .trailing,], 5)
                .textFieldStyle(RoundedStyle())
                .autocorrectionDisabled()
                .accessibilityIdentifier("networkingTests_URLTextField")
            Text("API Path: (/api/path) - Optional")
                .font(.embraceFont(size: 15))
                .foregroundStyle(.embraceSteel)
                .padding([.top, .leading, .bottom], 5)
            TextField("", text: $viewModel.api)
                .font(.embraceFont(size: 18))
                .foregroundStyle(.embraceSilver)
                .padding([.leading, .trailing,], 5)
                .textFieldStyle(RoundedStyle())
                .autocorrectionDisabled()
                .accessibilityIdentifier("networkingTests_APITextField")
            Section("Method") {
                NetworkingTestMethodTypeView(requestMethod: $viewModel.requestMethod)
            }
            Section("Request Body Properties") {
                NetworkingTestBodyPropertyView { key, value in
                    viewModel.addBodyProperty(key: key, value: value)
                }
            }
            TestScreenButtonView(viewModel: viewModel)
                .onAppear {
                    viewModel.spanExporter = spanExporter
                }
        }
    }
}

#Preview {
    let dataCollector = DataCollector()
    NetworkingTestUIComponent(dataModel: NetworkingTestsDataModel.networkCall)
        .environment(dataCollector)
}
