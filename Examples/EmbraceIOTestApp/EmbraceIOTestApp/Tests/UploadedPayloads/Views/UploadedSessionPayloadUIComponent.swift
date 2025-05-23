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
        self.viewModel = .init(dataModel: dataModel)
    }

    var body: some View {
        VStack(alignment: .leading) {
            Section("Current Session:") {
                Text("\(viewModel.currentSessionId ?? "-")")
                    .font(.embraceFont(size: 12))
                    .padding(.top, 2)
                    .padding(.bottom, 5)
                    .padding(.leading, 10)
            }
            Section("Last Session:") {
                Text("\(viewModel.lastSessionId ?? "-")")
                    .font(.embraceFont(size: 12))
                    .padding(.top, 2)
                    .padding(.bottom, 5)
                    .padding(.leading, 10)
            }
            Text("Manually background the app and reopen in order to kick off the session post process. After at least one session has been posted, a picker will appear with the last posted session selected by default.")
                .foregroundStyle(.embraceSteel)
                .font(.embraceFont(size: 12))
                .padding([.top, .bottom], 5)
            Section("Posted Session To Test:") {
                Picker("Posted Session", selection: $viewModel.selectedSessionId) {
                    ForEach(viewModel.exportedAndPostedSessions, id: \.self) {
                        Text($0)
                            .tag($0)
                            .font(.embraceFont(size: 12))
                            .foregroundColor(.embracePurple)
                    }
                }
            }
            .opacity(viewModel.exportedAndPostedSessions.count == 0 ? 0.0 : 1.0)
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
