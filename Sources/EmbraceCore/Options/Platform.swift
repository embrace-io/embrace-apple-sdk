//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

@objc(EMBPlatform)
/// Used to define the platform the current application is running on.
public enum Platform: Int {
    case iOS
    case iOSExtension
    case tvOS
    case unity
    case reactNative
    case flutter
}
