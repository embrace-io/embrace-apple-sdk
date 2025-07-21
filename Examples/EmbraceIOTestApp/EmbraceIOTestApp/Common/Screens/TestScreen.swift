//
//  TestScreen.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct TestScreen<T: RawRepresentable & CaseIterable & TestScreenDataModel>: View
where T.RawValue == Int, T.AllCases: RandomAccessCollection {
    @Environment(DataCollector.self) private var dataCollector

    var body: some View {
        ScrollView {
            ZStack {
                Spacer().containerRelativeFrame([.horizontal, .vertical])
                VStack {
                    ForEach(T.allCases, id: \.rawValue) { testCase in
                        testCase.uiComponent
                            .environment(dataCollector)
                    }
                }
            }
        }
    }
}

#Preview {
    let dataCollector = DataCollector()
    return TestScreen<ViewControllerTestsDataModel>()
        .environment(dataCollector)
}
