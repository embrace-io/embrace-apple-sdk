//
//  TestComponentViewResult.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

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
        TextComponentViewResult(result: .constant(.success))
        TextComponentViewResult(result: .constant(.fail))
        TextComponentViewResult(result: .constant(.testing))
        TextComponentViewResult(result: .constant(.unknown))
    }
}
