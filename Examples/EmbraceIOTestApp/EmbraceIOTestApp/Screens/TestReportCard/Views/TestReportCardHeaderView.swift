//
//  TestReportCardHeaderView.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct TestReportCardHeaderView: View {
    var passed: Bool
    var body: some View {
        VStack {
            Text("TEST RESULT:")
                .font(.embraceFont(size: 20))
            Text(passed ? "PASS" : "FAIL")
                .font(.embraceFont(size: 35))
                .foregroundStyle(passed ? .green : .red)
        }
    }
}

#Preview {
    return VStack {
        TestReportCardHeaderView(passed: true)
            .padding(.bottom, 40)
        TestReportCardHeaderView(passed: false)
    }
}
