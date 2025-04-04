//
//  TestScreen.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct TestScreen<T: RawRepresentable & CaseIterable & TestScreenDataModel>: View where T.RawValue == Int, T.AllCases: RandomAccessCollection {
    @Environment(TestSpanExporter.self) private var spanExporter
    @Environment(TestLogRecordExporter.self) private var logExporter

    var body: some View {
        ScrollView {
            ZStack {
                Spacer().containerRelativeFrame([.horizontal, .vertical])
                VStack {
                    ForEach(T.allCases, id: \.rawValue) { testCase in
                        testCase.uiComponent
                            .environment(spanExporter)
                            .environment(logExporter)
                    }
                }
            }
        }
    }
}

#Preview {
    let spanExporter = TestSpanExporter()
    let logRecordExporter = TestLogRecordExporter()
    TestScreen<ViewControllerTestsDataModel>()
        .environment(spanExporter)
        .environment(logRecordExporter)
}
