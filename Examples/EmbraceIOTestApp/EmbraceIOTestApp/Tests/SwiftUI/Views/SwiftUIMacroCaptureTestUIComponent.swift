//
//  SwiftUIMacroCaptureTestUIComponent.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct SwiftUIMacroCaptureTestUIComponent: View {
    @Environment(DataCollector.self) private var dataCollector
    private var spanExporter: TestSpanExporter {
        dataCollector.spanExporter
    }
    @State var dataModel: any TestScreenDataModel
    @State var viewModel: SwiftUICaptureTestViewModel

    @State var presentTestView: Bool = false

    init(dataModel: any TestScreenDataModel) {
        self.dataModel = dataModel
        viewModel = .init(dataModel: dataModel, captureType: .macro)
    }

    var body: some View {
        Rectangle()
            .frame(height: 1)
            .foregroundColor(.embraceSteel)
            .padding(.top, 15)
        Section {
            TestScreenButtonView(viewModel: viewModel)
                .onAppear {
                    viewModel.spanExporter = spanExporter
                }
                .sheet(isPresented: $viewModel.presentDummyView) {
                    SwiftUITestViewMacroCapture()
                }
        } header: {
            Text("Macro Capture")
                .textCase(nil)
                .font(.embraceFont(size: 18))
                .foregroundStyle(.embraceSilver)
        }
        .padding(.top, 15)
    }
}
