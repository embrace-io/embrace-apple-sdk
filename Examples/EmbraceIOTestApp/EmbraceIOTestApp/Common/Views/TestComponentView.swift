//
//  TestComponentView.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct TestComponentView: View {
    @Binding var testResult: TestResult
    @Binding var readyForTest: Bool
    var testName: String
    var testAction: () -> Void

    var body: some View {
        HStack {
            Button {
                testAction()
            } label: {
                TestComponentViewLabel(text: testName, result: $testResult)
                    .foregroundStyle(.embraceSilver.opacity(readyForTest ? 1.0 : 0.5))
            }
            .disabled(!readyForTest)
        }
        .frame(height: 60)
        .background(testResult.resultColor)
    }
}

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

struct TextComponentViewResult: View {
    @Binding var result: TestResult
    private var icon: String {
        switch result {
        case .fail:
            "xmark.circle.fill"
        case .unknown, .testing:
            "questionmark.circle.fill"
        case .success:
            "checkmark.circle.fill"
        }
    }
    var body: some View {
        Text(.init(systemName: icon))
            .padding(.trailing, 20)
            .font(.system(size: 30, weight: .heavy, design: .rounded))
            .opacity(0.5)
            .shadow(color: .black, radius: 5)
    }
}

#Preview {
    VStack {
        TestComponentView(testResult: .constant(.unknown),
                          readyForTest: .constant(true),
                          testName: "Test",
                          testAction: {})
        TestComponentView(testResult: .constant(.unknown),
                          readyForTest: .constant(false),
                          testName: "Test",
                          testAction: {})
        TestComponentView(testResult: .constant(.testing),
                          readyForTest: .constant(false),
                          testName: "Test",
                          testAction: {})
        TestComponentView(testResult: .constant(.success),
                          readyForTest: .constant(true),
                          testName: "Test",
                          testAction: {})
        TestComponentView(testResult: .constant(.success),
                          readyForTest: .constant(false),
                          testName: "Test",
                          testAction: {})
        TestComponentView(testResult: .constant(.fail),
                          readyForTest: .constant(true),
                          testName: "Test",
                          testAction: {})
        TestComponentView(testResult: .constant(.fail),
                          readyForTest: .constant(false),
                          testName: "Test",
                          testAction: {})
    }
}
