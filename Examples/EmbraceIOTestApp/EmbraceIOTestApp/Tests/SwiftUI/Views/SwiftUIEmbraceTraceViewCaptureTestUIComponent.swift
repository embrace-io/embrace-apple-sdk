//
//  SwiftUIEmbraceTraceViewCaptureTestUIComponent.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct SwiftUIEmbraceTraceViewCaptureTestUIComponent: View {
    @Environment(DataCollector.self) private var dataCollector
    private var spanExporter: TestSpanExporter {
        dataCollector.spanExporter
    }
    @State var dataModel: any TestScreenDataModel
    @State var viewModel: SwiftUICaptureTestViewModel

    @State var presentTestView: Bool = false

    init(dataModel: any TestScreenDataModel) {
        self.dataModel = dataModel
        viewModel = .init(dataModel: dataModel, captureType: .embraceView)
    }

    var body: some View {
        Rectangle()
            .frame(height: 1)
            .foregroundColor(.embraceSteel)
            .padding(.top, 15)
        Section {
            VStack(alignment: .leading) {
                Section {
                    SwiftUITestsLoadedPropertyView(loadedState: $viewModel.loadedState)
                } header: {
                    Text("Loaded property")
                        .textCase(nil)
                        .font(.embraceFont(size: 15))
                        .foregroundStyle(.embraceSilver)
                }
                Section {
                    SwiftUITestsAttributesView { key, value in
                        viewModel.addAttribute(key: key, value: value)
                    }
                } header: {
                    Text("View Attributes")
                        .textCase(nil)
                        .font(.embraceFont(size: 15))
                        .foregroundStyle(.embraceSilver)
                }
                TestScreenButtonView(viewModel: viewModel)
                    .onAppear {
                        viewModel.spanExporter = spanExporter
                    }
                    .sheet(isPresented: $viewModel.presentDummyView) {
                        SwiftUITestViewEmbraceViewCapture()
                    }
            }
        } header: {
            Text("Embrace Trace View Capture")
                .textCase(nil)
                .font(.embraceFont(size: 18))
                .foregroundStyle(.embraceSilver)
        }
        .padding(.top, 15)
    }
}
