//
//  TestViewModelState.swift
//  EmbraceIOTestApp
//
//

import Foundation

enum TestViewModelState {
    case idle(Bool)
    case testing
    case testComplete(TestResult)
}

extension TestViewModelState: Equatable {
    static func == (lhs: TestViewModelState, rhs: TestViewModelState) -> Bool {
        switch (lhs, rhs) {
        case (let .testComplete(lhsResult), let .testComplete(rhsResult)):
            return lhsResult == rhsResult
        case (let .idle(lhsStarted), let .idle(rhsStarted)):
            return lhsStarted == rhsStarted
        case (.testing, .testing):
            return true
        default:
            return false
        }
    }
}
