//
//  TestComponentViewLabel.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct TestComponentViewLabel: View {
    var text: String
    @Binding var result: TestResult

    private var isTesting: Bool {
        result == .testing
    }
    var body: some View {
        HStack {
            Text(text)
                .font(.embraceFont(size: 18))
                .padding(.leading, 20)
                .padding(.trailing, 60)
            Spacer()
            ZStack {
                TextComponentViewResult(result: $result)
                    .opacity(isTesting ? 0 : 1.0)
                ProgressView()
                    .controlSize(.large)
                    .padding(.trailing, 20)
                    .opacity(isTesting ? 1.0 : 0)
            }
        }
    }
}

#Preview {
    VStack {
        TestComponentViewLabel(text: "Test", result: .constant(.success))
        TestComponentViewLabel(text: "Test", result: .constant(.testing))
        TestComponentViewLabel(text: "Test", result: .constant(.unknown))
        TestComponentViewLabel(text: "Test", result: .constant(.fail))
    }
}
