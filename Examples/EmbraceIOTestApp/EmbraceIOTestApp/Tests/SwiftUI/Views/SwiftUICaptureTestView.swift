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

    init(dataModel: any TestScreenDataModel) {
        self.dataModel = dataModel
        viewModel = .init(dataModel: dataModel)
    }

    var body: some View {
        TestScreenButtonView(viewModel: viewModel)
            .onAppear {
                viewModel.spanExporter = spanExporter
            }
            .sheet(isPresented: $presentTestView) {
                SwiftUITestView()
            }
    }
}

private struct SwiftUITestView: View {
    var body: some View {
        Text("👀 Don't mind me!")
    }
}

#Preview {
    SwiftUITestView()
}
