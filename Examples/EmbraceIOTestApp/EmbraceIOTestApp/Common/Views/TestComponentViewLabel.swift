//
//  TestComponentViewLabel.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct TestComponentViewLabel: View {
    var text: String
    var state: TestViewModelState

    private var isTesting: Bool {
        state == .testing
    }

    private var result: TestResult {
        switch state {
        case .idle:
                .unknown
        case .testing:
                .testing
        case .testComplete(let result):
            result
        }
    }

    var body: some View {
        HStack {
            Text(text)
                .font(.embraceFont(size: 18))
                .padding(.leading, 20)
                .padding(.trailing, 60)
            Spacer()
            ZStack {
                TextComponentViewResult(result: .constant(result))
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
    return VStack {
        TestComponentViewLabel(text: "Test", state: .testComplete(.success))
        TestComponentViewLabel(text: "Test", state: .testing)
        TestComponentViewLabel(text: "Test", state: .idle(false))
        TestComponentViewLabel(text: "Test", state: .idle(true))
        TestComponentViewLabel(text: "Test", state: .testComplete(.fail))
        TestComponentViewLabel(text: "A very, very large multiline text", state: .idle(false))
    }
}
