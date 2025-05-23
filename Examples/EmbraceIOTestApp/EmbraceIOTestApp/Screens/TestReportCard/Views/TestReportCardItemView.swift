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
                Image(systemName: iconName(for: item.result))
                    .foregroundStyle(item.result.resultColor)
                    .frame(width: 20, alignment: .trailing)
                    .padding(.trailing, 5)
            }
        }
    }

    private func iconName(for result: TestResult) -> String {
        switch result {
        case .fail:
            "xmark"
        case .success:
            "checkmark"
        case .warning:
            "exclamationmark"
        default:
            "questionmark"
        }
    }
}


#Preview {
    var passedItem: TestReportItem = .init(target: "viewDidLoad", expected: "viewDidLoad", recorded: "found", result: .success)
    var failItem: TestReportItem = .init(target: "viewDidLoad", expected: "viewDidLoad", recorded: "not found", result: .fail)
    var warningItem: TestReportItem = .init(target: "viewDidLoad", expected: "viewDidLoad", recorded: "not found", result: .warning)
    return VStack {
        TestReportCardItemView(item: passedItem)
            .padding(.bottom, 40)
        TestReportCardItemView(item: failItem)
            .padding(.bottom, 40)
        TestReportCardItemView(item: warningItem)
    }
}
