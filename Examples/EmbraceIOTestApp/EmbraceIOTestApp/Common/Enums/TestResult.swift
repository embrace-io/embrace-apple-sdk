//
//  TestResult.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

enum TestResult {
    case unknown
    case testing
    case success
    case fail

    var resultColor: Color {
        switch self {
        case .unknown, .testing: .gray
        case .success: .green
        case .fail: .red
        }
    }
}
