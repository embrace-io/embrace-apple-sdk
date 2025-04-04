//
//  TestReportCardHeaderView.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct TestReportCardHeaderView: View {
    var passed: Bool
    var body: some View {
        Text(passed ? "PASS" : "FAIL")
            .font(.embraceFont(size: 35))
            .foregroundStyle(passed ? .green : .red)
    }
}

#Preview {
    TestReportCardHeaderView(passed: true)
        .padding(.bottom, 40)
    TestReportCardHeaderView(passed: false)
}
