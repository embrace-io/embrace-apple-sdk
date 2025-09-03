//
//  PerformanceTestSpansView.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct PerformanceTestSpansUIComponent: View {
    @Environment(DataCollector.self) private var dataCollector
    private var spanExporter: TestSpanExporter {
        dataCollector.spanExporter
    }
    @State var dataModel: any TestScreenDataModel

    @State private var viewModel: PerformanceTestSpansViewModel

    init(dataModel: any TestScreenDataModel) {
        self.dataModel = dataModel
        self.viewModel = PerformanceTestSpansViewModel(dataModel: dataModel)
    }

    var body: some View {
        VStack(alignment: .leading) {
            Section {
                VStack {
                    PerformanceTestSliderView(title: "Number of concurrent loops", maxValue: viewModel.maxConcurrentLoops, value: $viewModel.numberOfConcurrentLoops)
                    PerformanceTestSliderView(title: "Number of calculations loops", maxValue: viewModel.maxCalculationsPerLoop, value: $viewModel.numberOfCalculationsPerLoop)
                    PerformanceTestSliderView(title: "Limit Number of Spans per loop", maxValue: viewModel.maxNumberOfSpansPerLoop, value: $viewModel.limitNumberOfSpansPerLoop)
                    TestScreenButtonView(viewModel: viewModel)
                        .onAppear {
                            viewModel.spanExporter = spanExporter
                        }
                }
            } header: {
                Text("Spans Stress Test")
                    .textCase(nil)
                    .font(.embraceFont(size: 18))
                    .foregroundStyle(.embraceSilver)
            }
            .padding(.top, 15)
        }
    }
}
