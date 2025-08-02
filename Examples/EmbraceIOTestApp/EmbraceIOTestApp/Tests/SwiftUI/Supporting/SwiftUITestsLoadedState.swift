//
//  SwiftUITestsLoadedState.swift
//  EmbraceIOTestApp
//
//

enum SwiftUITestsLoadedState: Int, CaseIterable {
    case dontInclude
    case `true`
    case `false`

    var text: String {
        switch self {
        case .dontInclude:
            "Don't Include"
        case .true:
            "true"
        case .false:
            "false"
        }
    }

    var identifier: String {
        switch self {
        case .dontInclude:
            "SwiftUITestsLoadedState_dontInclude"
        case .true:
            "SwiftUITestsLoadedState_true"
        case .false:
            "SwiftUITestsLoadedState_false"
        }
    }

    var boolValue: Bool? {
        switch self {
        case .dontInclude:
            return nil
        case .true:
            return true
        case .false:
            return false
        }
    }
}
