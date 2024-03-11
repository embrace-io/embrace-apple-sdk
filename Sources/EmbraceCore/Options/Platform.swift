//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

@objc(EMBPlatform)
/// Used to define the platform the current application is running on.
public enum Platform: Int {
    case unity
    case reactNative
    case flutter
    case native

    public static let `default`: Platform = .native
}

extension Platform {
    var frameworkId: String {
        switch self {
        case .native: return "native"
        case .reactNative: return "react_native"
        case .unity: return "unity"
        case .flutter: return "flutter"
        }
    }
}
