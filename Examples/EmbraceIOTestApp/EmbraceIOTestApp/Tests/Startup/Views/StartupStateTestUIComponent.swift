//
//  StartupStateTestUIComponent.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct StartupStateTestUIComponent: View {
    @Environment(DataCollector.self) private var dataCollector
    private var spanExporter: TestSpanExporter {
        dataCollector.spanExporter
    }
    @State var dataModel: any TestScreenDataModel
    @State private var viewModel: StartupStateTestViewModel

    init(dataModel: any TestScreenDataModel) {
        self.dataModel = dataModel
        self.viewModel = .init(dataModel: dataModel)
    }

    var body: some View {
            VStack {
                Toggle("Cold Start State Expected", isOn: $viewModel.coldStartExpected)
                    .font(.embraceFont(size: 18))
                    .tint(.embracePurple)
                    .accessibilityIdentifier("coldStartExpectedToggle")
                    .padding([.leading, .trailing, .bottom], 5)
                TestScreenButtonView(viewModel: viewModel)
                    .onAppear {
                        viewModel.spanExporter = spanExporter
                    }
            }
            .padding([.top], 15)
    }
}

#Preview {
    let dataCollector = DataCollector()
    return StartupStateTestUIComponent(dataModel: UploadedPayloadsTestsDataModel.sessionPayload)
        .environment(dataCollector)
}
