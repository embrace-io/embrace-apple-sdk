//
//  TestResultsScreen.swift
//  EmbraceIOTestApp
//
//

import SwiftUI



struct TestReportCard: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var report: TestReport
    var body: some View {
        VStack {
            Text(report.passed ? "PASS" : "FAIL")
                .font(.largeTitle)
                .foregroundStyle(.white)
                .padding(.bottom, 60)
            VStack{
                HStack {
                    Text("Target")
                        .font(.embraceFont(size: 12))
                        .frame(width: 100, alignment: .leading)
                    Text("Expected")
                        .font(.embraceFont(size: 12))
                        .frame(width: 100, alignment: .leading)
                    Text("Recorded")
                        .font(.embraceFont(size: 12))
                        .frame(width: 100, alignment: .leading)
                    Spacer()
                }
            }
            .padding(.leading, 5)
            List(report.items) { item in
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
                .listRowInsets(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 0))
            }
            .contentMargins(0)
        }
    }
}

#Preview {
    @Previewable @State var reports: TestReport =
        .init(result: .fail, items: [
            .init(target: "viewDidLoad", expected: "viewDidLoad", recorded: "found", result: .success),
            .init(target: "customViewName", expected: "A custom Name", recorded: "View Controller", result: .fail)
        ])
    @Previewable @State var presented: Bool = false
    VStack {
        Button {
            presented.toggle()
        } label: {
            Text("Display Report")
        }
    }
    .sheet(isPresented: $presented) {
        TestReportCard(report: $reports)
    }

}
