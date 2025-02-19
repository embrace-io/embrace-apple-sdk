//
//  LoggingTestLogMessageUIComponent.swift
//  EmbraceIOTestApp
//
//

import EmbraceIO
import SwiftUI

struct LoggingTestLogMessageUIComponent: View {
    @Environment(TestLogRecordExporter.self) private var logExporter
    @State var dataModel: any TestScreenDataModel
    @State private var viewModel: LoggingTestErrorMessageViewModel

    init(dataModel: any TestScreenDataModel) {
        self.dataModel = dataModel
        viewModel = .init(dataModel: dataModel)
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Logging Message")
                .font(.embraceFont(size: 15))
                .foregroundStyle(.embraceSteel)
                .padding([.leading, .bottom], 5)
            TextField("Enter a message to log", text: $viewModel.message)
                .font(.embraceFont(size: 18))
                .backgroundStyle(.red)
                .foregroundStyle(.embraceSilver)
                .padding([.leading, .trailing,], 5)
                .textFieldStyle(RoundedStyle())
            TestScreenButtonView(viewModel: viewModel)
                .onAppear {
                    viewModel.logExporter = logExporter
                }
        }
    }
}

#Preview {
    let logExporter = TestLogRecordExporter()
    LoggingTestLogMessageUIComponent(dataModel: LoggingTestScreenDataModel.errorLogMessage)
        .environment(logExporter)
}
