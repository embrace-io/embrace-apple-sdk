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
    case warning
    case fail

    var resultColor: Color {
        switch self {
        case .unknown, .testing: .gray
        case .success: .green
        case .warning: .yellow
        case .fail: .red
        }
    }
}
