//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

/// Used to define the platform the current application is running on.
public enum Platform: Int {
    case unity
    case reactNative
    case flutter
    case native

    public static let `default`: Platform = .native
}

extension Platform {
    var frameworkId: Int {
        switch self {
        case .native: return 1
        case .reactNative: return 2
        case .unity: return 3
        case .flutter: return 4
        }
    }
}
