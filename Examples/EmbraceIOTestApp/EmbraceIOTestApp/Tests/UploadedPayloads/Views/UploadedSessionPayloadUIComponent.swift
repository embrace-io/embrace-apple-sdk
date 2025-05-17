//
//  UploadedSessionPayloadUIComponent.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct UploadedSessionPayloadUIComponent: View {
    @Environment(DataCollector.self) private var dataCollector

    @State var dataModel: any TestScreenDataModel
    @State private var viewModel: UploadedSessionPayloadTestViewModel

    init(dataModel: any TestScreenDataModel) {
        self.dataModel = dataModel
        viewModel = .init(dataModel: dataModel)
    }

    var body: some View {
        VStack {
            Text("Current Session: \(viewModel.currentSessionId ?? "-")")
                .font(.embraceFont(size: 12))
            Text("Last Session: \(viewModel.lastSessionId ?? "-")")
                .font(.embraceFont(size: 12))

            Picker("Posted Session", selection: $viewModel.selectedSessionIdIndex) {
                ForEach(viewModel.exportedAndPostedSessions, id: \.self) {
                    Text($0)
                        .font(.embraceFont(size: 12))
                }
            }
            .pickerStyle(.wheel)

            TestScreenButtonView(viewModel: viewModel)
                .disabled(viewModel.testButtonDisabled)
                .onAppear {
                    viewModel.dataCollector = dataCollector
                }
        }
    }
}

#Preview {
    let dataCollector = DataCollector()
    UploadedSessionPayloadUIComponent(dataModel: UploadedPayloadsTestsDataModel.sessionPayload)
        .environment(dataCollector)
}
