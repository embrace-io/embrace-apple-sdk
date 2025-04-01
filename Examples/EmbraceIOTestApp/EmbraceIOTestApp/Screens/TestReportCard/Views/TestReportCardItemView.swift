//
//  TestReportCardItemView.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct TestReportCardItemView: View {
    var item: TestReportItem
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(item.target)
                    .font(.embraceFont(size: 11))
                    .frame(width: 100, alignment: .leading)
                Text(item.expected)
                    .font(.embraceFont(size: 11))
                    .frame(width: 100, alignment: .leading)
                Text(item.recorded)
                    .font(.embraceFont(size: 11))
                    .frame(width: 100, alignment: .leading)
                Spacer()
                Image(systemName: item.passed ? "checkmark" : "xmark")
                    .foregroundStyle(item.passed ? .green : .red)
                    .frame(width: 20, alignment: .trailing)
                    .padding(.trailing, 5)
            }
        }
    }
}

#Preview {
    @Previewable var passedItem: TestReportItem = .init(target: "viewDidLoad", expected: "viewDidLoad", recorded: "found", result: .success)
    @Previewable var failItem: TestReportItem = .init(target: "viewDidLoad", expected: "viewDidLoad", recorded: "not found", result: .fail)
    TestReportCardItemView(item: passedItem)
        .padding(.bottom, 40)
    TestReportCardItemView(item: failItem)
}
