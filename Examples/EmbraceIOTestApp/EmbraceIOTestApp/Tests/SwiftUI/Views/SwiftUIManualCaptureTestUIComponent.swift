//
//  SwiftUIManualCaptureTestUIComponent.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct SwiftUIManualCaptureTestUIComponent: View {
    @Environment(DataCollector.self) private var dataCollector
    private var spanExporter: TestSpanExporter {
        dataCollector.spanExporter
    }
    @State var dataModel: any TestScreenDataModel
    @State var viewModel: SwiftUICaptureTestViewModel

    @State var presentTestView: Bool = false
    @State private var onLoaded: Bool = false
    init(dataModel: any TestScreenDataModel) {
        self.dataModel = dataModel
        viewModel = .init(dataModel: dataModel, captureType: .manual)
    }

    var body: some View {
        Section {
            VStack(alignment: .leading) {
                Section {
                    SwiftUITestsLoadedPropertyView(
                        loadedState: $viewModel.contentComplete,
                        toggleIdentifier: "manualCaptureContentComplete")
                } header: {
                    Text("Content Complete")
                        .textCase(nil)
                        .font(.embraceFont(size: 15))
                        .foregroundStyle(.embraceSilver)
                }
                Section {
                    SwiftUITestsAttributesView(keyIdentifier: "manualCapturePropertyKey", valueIdentifier: "manualCapturePropertyValue", addIdentifier: "manualCaptureAddProperty") { key, value in
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
                        SwiftUITestViewManualCapture()
                            .embraceTrace(
                                "TestDummyView",
                                attributes: viewModel.attributes,
                                contentComplete: onLoaded
                            )
                            .onAppear {
                                if viewModel.contentComplete {
                                    onLoaded = true
                                }
                            }
                            .onDisappear {
                                onLoaded = false
                            }
                    }
            }
        } header: {
            Text("Manual Capture")
                .textCase(nil)
                .font(.embraceFont(size: 18))
                .foregroundStyle(.embraceSilver)
        }
        .onChange(of: viewModel.contentComplete) {
            onLoaded = false
        }
        .padding(.top, 15)
    }
}
