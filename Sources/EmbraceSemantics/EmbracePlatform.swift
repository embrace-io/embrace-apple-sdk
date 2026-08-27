//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

/// Used to define the platform the current application is running on.
public enum EmbracePlatform: Int {
    case native = 1
    case reactNative = 2
    case unity = 3
    case flutter = 4

    public static let `default`: EmbracePlatform = .native
}
