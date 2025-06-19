//
//  EmbraceInitForceState.swift
//  EmbraceIOTestApp
//
//

enum EmbraceInitForceState: Int, CaseIterable {
    case off = 0
    case cold
    case warm

    var text: String {
        switch self {
        case .off:
            "off"
        case .cold:
            "cold"
        case .warm:
            "warm"
        }
    }

    var identifier: String {
        switch self {
        case .off:
            "EmbraceInitForceState_Off"
        case .cold:
            "EmbraceInitForceState_Cold"
        case .warm:
            "EmbraceInitForceState_Warm"
        }
    }
}
