//
//  SwiftUICaptureTestView.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct SwiftUICaptureTestView: View {
    @Environment(DataCollector.self) private var dataCollector
    private var spanExporter: TestSpanExporter {
        dataCollector.spanExporter
    }
    @State var dataModel: any TestScreenDataModel
    @State var viewModel: SwiftUICaptureTestViewModel

    @State var presentTestView: Bool = false

    init(dataModel: any TestScreenDataModel, captureType: SwiftUICaptureType) {
        self.dataModel = dataModel
        viewModel = .init(dataModel: dataModel, captureType: captureType)
    }

    var body: some View {
        TestScreenButtonView(viewModel: viewModel)
            .onAppear {
                viewModel.spanExporter = spanExporter
            }
            .sheet(isPresented: $viewModel.presentDummyViewManual) {
                SwiftUITestViewManualCapture()
                    .embraceTrace("TestDummyView")
            }
            .sheet(isPresented: $viewModel.presentDummyViewMacro) {
                SwiftUITestViewMacroCapture()
            }
            .sheet(isPresented: $viewModel.presentDummyViewEmbraceView) {
                SwiftUITestViewEmbraceViewCapture()
            }
    }
}
