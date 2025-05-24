//
//  SessionTestFinishedSessionUIComponent.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct SessionTestFinishedSessionUIComponent: View {
    @Environment(DataCollector.self) private var dataCollector
    private var spanExporter: TestSpanExporter {
        dataCollector.spanExporter
    }
    @State var dataModel: any TestScreenDataModel
    @State private var viewModel: SessionTestFinishedSessionTestViewModel

    init(dataModel: any TestScreenDataModel) {
        self.dataModel = dataModel
        viewModel = .init(dataModel: dataModel)
    }

    var body: some View {
        VStack {
            Text("If \"Fake App State Switch\" is OFF, you need to manually background and relaunch the app after initializing the payload test in order to start the procedure that ends a session and exports a payload.")
                .foregroundStyle(.embraceSteel)
            Toggle("Fake App State Switch", isOn: $viewModel.fakeAppState)
                .tint(.embracePurple)
                .padding([.leading, .trailing, .bottom], 5)
            TestScreenButtonView(viewModel: viewModel)
                .onAppear {
                    viewModel.spanExporter = spanExporter
                }
        }
    }
}

#Preview {
    let dataCollector = DataCollector()
    return SessionTestFinishedSessionUIComponent(dataModel: SessionTestsDataModel.finishedSessionPayload)
        .environment(dataCollector)
}
