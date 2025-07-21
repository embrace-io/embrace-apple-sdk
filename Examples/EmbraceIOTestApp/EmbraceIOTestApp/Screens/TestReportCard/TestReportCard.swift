//
//  TestReportCard.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct TestReportCard: View {
    @Environment(\.dismiss) private var dismiss
    var report: TestReport
    var body: some View {
        VStack {
            TestReportCardHeaderView(passed: report.passed)
                .padding(.top, 20)
                .padding(.bottom, 60)
            TestReportCardSectionsView()
                .padding(.leading, 5)
            List(report.items) { item in
                TestReportCardItemView(item: item)
                    .listRowInsets(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 0))
            }
            .contentMargins(0)
        }
    }
}

#Preview {
    @State var passReport: TestReport =
        .init(items: [
            .init(target: "viewDidLoad", expected: "viewDidLoad", recorded: "found", result: .success),
            .init(target: "customViewName", expected: "A custom Name", recorded: "View Controller", result: .success),
        ])
    @State var failReport: TestReport =
        .init(items: [
            .init(target: "viewDidLoad", expected: "viewDidLoad", recorded: "found", result: .success),
            .init(target: "customViewName", expected: "A custom Name", recorded: "View Controller", result: .fail),
        ])

    @State var passedPresented: Bool = false
    @State var failPresented: Bool = false

    return VStack {
        Button {
            passedPresented.toggle()
        } label: {
            Text("PASSED Report")
        }
        .padding(.bottom, 60)
        Button {
            failPresented.toggle()
        } label: {
            Text("FAIL Report")
        }
    }
    .sheet(isPresented: $passedPresented) {
        TestReportCard(report: passReport)
    }
    .sheet(isPresented: $failPresented) {
        TestReportCard(report: failReport)
    }
    .preferredColorScheme(.dark)

}
