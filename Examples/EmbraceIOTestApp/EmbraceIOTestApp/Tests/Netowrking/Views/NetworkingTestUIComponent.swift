//
//  NetworkingTestUIComponent.swift
//  EmbraceIOTestApp
//
//

import EmbraceIO
import SwiftUI

struct NetworkingTestUIComponent: View {
    @Environment(TestSpanExporter.self) private var spanExporter
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
            TextField("https://www.embrace.io", text: $viewModel.testURL)
                .font(.embraceFont(size: 18))
                .foregroundStyle(.embraceSilver)
                .padding([.leading, .trailing,], 5)
                .textFieldStyle(RoundedStyle())
                .accessibilityIdentifier("networkingTests_URLTextField")
            Section("Method") {
                NetworkingTestMethodTypeView(requestMethod: $viewModel.requestMethod)
            }
            TestScreenButtonView(viewModel: viewModel)
                .onAppear {
                    viewModel.spanExporter = spanExporter
                }
        }
    }
}

#Preview {
    let spanExporter = TestSpanExporter()
    NetworkingTestUIComponent(dataModel: NetworkingTestsDataModel.networkCall)
        .environment(spanExporter)
}
